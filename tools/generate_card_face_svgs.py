#!/usr/bin/env python3
"""Generate editable Dream Glass card-face SVG sources.

The implementation uses only the Python standard library. It reads TrueType
metrics for deterministic fitting; the PowerShell pathification step converts
the source `<text>` elements into runtime glyph paths for Godot/ThorVG.
"""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import struct
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable


CYAN = "#59E6DB"
VIOLET = "#D27BE5"
IVORY = "#F4F0FF"
MUTED = "#AAA4C1"
GLASS = "#0E0B26"
DEEP = "#080619"
SUIT_IDENTITY_COLORS = {
    "♥": "#FF5C8A",
    "♠": "#8EA7FF",
    "♦": "#FFB547",
    "♣": "#65D6A6",
}


def identity_color(identity: str) -> str:
    if not identity:
        raise ValueError("card identity must not be empty")
    try:
        return SUIT_IDENTITY_COLORS[identity[0]]
    except KeyError as error:
        raise ValueError(f"unsupported card suit in identity: {identity}") from error


def _u16(data: bytes, offset: int) -> int:
    return struct.unpack_from(">H", data, offset)[0]


def _i16(data: bytes, offset: int) -> int:
    return struct.unpack_from(">h", data, offset)[0]


def _u32(data: bytes, offset: int) -> int:
    return struct.unpack_from(">I", data, offset)[0]


def _f2dot14(data: bytes, offset: int) -> float:
    return _i16(data, offset) / 16384.0


def _fmt(value: float) -> str:
    rounded = round(value, 2)
    if abs(rounded - round(rounded)) < 0.001:
        return str(int(round(rounded)))
    return f"{rounded:.2f}".rstrip("0").rstrip(".")


@dataclass(frozen=True)
class Point:
    x: float
    y: float
    on_curve: bool


class TrueTypeFont:
    MORE_COMPONENTS = 0x0020
    ARG_1_AND_2_ARE_WORDS = 0x0001
    ARGS_ARE_XY_VALUES = 0x0002
    WE_HAVE_A_SCALE = 0x0008
    WE_HAVE_AN_X_AND_Y_SCALE = 0x0040
    WE_HAVE_A_TWO_BY_TWO = 0x0080
    WE_HAVE_INSTRUCTIONS = 0x0100

    def __init__(self, path: Path) -> None:
        self.path = path
        self.data = path.read_bytes()
        self.sha256 = hashlib.sha256(self.data).hexdigest()
        num_tables = _u16(self.data, 4)
        self.tables: dict[str, tuple[int, int]] = {}
        for index in range(num_tables):
            offset = 12 + index * 16
            tag = self.data[offset : offset + 4].decode("latin-1")
            self.tables[tag] = (_u32(self.data, offset + 8), _u32(self.data, offset + 12))
        required = {"cmap", "glyf", "head", "hhea", "hmtx", "loca", "maxp"}
        missing = required.difference(self.tables)
        if missing:
            raise ValueError(f"font is missing TrueType tables: {sorted(missing)}")
        head = self.tables["head"][0]
        self.units_per_em = _u16(self.data, head + 18)
        self.loca_format = _i16(self.data, head + 50)
        self.num_glyphs = _u16(self.data, self.tables["maxp"][0] + 4)
        self.num_h_metrics = _u16(self.data, self.tables["hhea"][0] + 34)
        self.glyph_offsets = self._read_loca()
        self.advance_widths = self._read_hmtx()
        self.cmap = self._read_cmap()

    def _read_loca(self) -> list[int]:
        offset = self.tables["loca"][0]
        if self.loca_format == 0:
            return [_u16(self.data, offset + index * 2) * 2 for index in range(self.num_glyphs + 1)]
        return [_u32(self.data, offset + index * 4) for index in range(self.num_glyphs + 1)]

    def _read_hmtx(self) -> list[int]:
        offset = self.tables["hmtx"][0]
        widths = [_u16(self.data, offset + index * 4) for index in range(self.num_h_metrics)]
        if self.num_h_metrics < self.num_glyphs:
            widths.extend([widths[-1]] * (self.num_glyphs - self.num_h_metrics))
        return widths

    def _read_cmap(self) -> dict[int, int]:
        table_offset = self.tables["cmap"][0]
        count = _u16(self.data, table_offset + 2)
        candidates: list[tuple[int, int, int]] = []
        for index in range(count):
            record = table_offset + 4 + index * 8
            platform = _u16(self.data, record)
            encoding = _u16(self.data, record + 2)
            subtable = table_offset + _u32(self.data, record + 4)
            fmt = _u16(self.data, subtable)
            priority = 0
            if fmt == 12 and (platform == 0 or (platform == 3 and encoding == 10)):
                priority = 3
            elif fmt == 4 and (platform == 0 or platform == 3):
                priority = 2
            if priority:
                candidates.append((priority, fmt, subtable))
        if not candidates:
            raise ValueError("font has no supported Unicode cmap")
        _, fmt, offset = max(candidates)
        return self._read_cmap12(offset) if fmt == 12 else self._read_cmap4(offset)

    def _read_cmap12(self, offset: int) -> dict[int, int]:
        groups = _u32(self.data, offset + 12)
        result: dict[int, int] = {}
        for index in range(groups):
            group = offset + 16 + index * 12
            start = _u32(self.data, group)
            end = _u32(self.data, group + 4)
            glyph = _u32(self.data, group + 8)
            for codepoint in range(start, end + 1):
                result[codepoint] = glyph + codepoint - start
        return result

    def _read_cmap4(self, offset: int) -> dict[int, int]:
        seg_count = _u16(self.data, offset + 6) // 2
        end_codes = offset + 14
        start_codes = end_codes + seg_count * 2 + 2
        id_deltas = start_codes + seg_count * 2
        id_ranges = id_deltas + seg_count * 2
        result: dict[int, int] = {}
        for index in range(seg_count):
            start = _u16(self.data, start_codes + index * 2)
            end = _u16(self.data, end_codes + index * 2)
            delta = _i16(self.data, id_deltas + index * 2)
            range_offset = _u16(self.data, id_ranges + index * 2)
            if start == 0xFFFF:
                continue
            for codepoint in range(start, end + 1):
                if range_offset == 0:
                    glyph = (codepoint + delta) & 0xFFFF
                else:
                    address = id_ranges + index * 2 + range_offset + (codepoint - start) * 2
                    glyph = _u16(self.data, address)
                    if glyph:
                        glyph = (glyph + delta) & 0xFFFF
                result[codepoint] = glyph
        return result

    def glyph_id(self, character: str) -> int:
        glyph = self.cmap.get(ord(character), 0)
        if glyph == 0 and character != " ":
            raise ValueError(f"font has no glyph for U+{ord(character):04X} {character!r}")
        return glyph

    def text_width(self, text: str, size: float) -> float:
        return sum(self.advance_widths[self.glyph_id(char)] for char in text) * size / self.units_per_em

    def text_path(
        self,
        text: str,
        x: float,
        baseline: float,
        size: float,
        anchor: str = "start",
        max_width: float | None = None,
    ) -> tuple[list[str], float]:
        width = self.text_width(text, size)
        if max_width is not None and width > max_width:
            size *= max_width / width
            width = max_width
        pen_x = x
        if anchor == "middle":
            pen_x -= width / 2
        elif anchor == "end":
            pen_x -= width
        scale = size / self.units_per_em
        paths: list[str] = []
        for character in text:
            glyph = self.glyph_id(character)
            for contour in self.glyph_contours(glyph):
                commands = self._contour_commands(contour, pen_x, baseline, scale)
                if commands:
                    paths.append(" ".join(commands))
            pen_x += self.advance_widths[glyph] * scale
        return paths, size

    def glyph_contours(
        self,
        glyph_id: int,
        transform: tuple[float, float, float, float, float, float] = (1, 0, 0, 1, 0, 0),
        depth: int = 0,
    ) -> list[list[Point]]:
        if depth > 16:
            raise ValueError("composite glyph nesting is too deep")
        glyf_offset = self.tables["glyf"][0]
        start = glyf_offset + self.glyph_offsets[glyph_id]
        end = glyf_offset + self.glyph_offsets[glyph_id + 1]
        if start == end:
            return []
        contour_count = _i16(self.data, start)
        if contour_count >= 0:
            contours = self._simple_glyph(start, contour_count)
            return [self._transform_contour(contour, transform) for contour in contours]
        return self._composite_glyph(start, transform, depth)

    def _simple_glyph(self, start: int, contour_count: int) -> list[list[Point]]:
        if contour_count == 0:
            return []
        cursor = start + 10
        endpoints = [_u16(self.data, cursor + index * 2) for index in range(contour_count)]
        cursor += contour_count * 2
        instruction_length = _u16(self.data, cursor)
        cursor += 2 + instruction_length
        point_count = endpoints[-1] + 1
        flags: list[int] = []
        while len(flags) < point_count:
            flag = self.data[cursor]
            cursor += 1
            flags.append(flag)
            if flag & 0x08:
                repeat = self.data[cursor]
                cursor += 1
                flags.extend([flag] * repeat)
        xs: list[int] = []
        current = 0
        for flag in flags:
            if flag & 0x02:
                delta = self.data[cursor]
                cursor += 1
                current += delta if flag & 0x10 else -delta
            elif not flag & 0x10:
                current += _i16(self.data, cursor)
                cursor += 2
            xs.append(current)
        ys: list[int] = []
        current = 0
        for flag in flags:
            if flag & 0x04:
                delta = self.data[cursor]
                cursor += 1
                current += delta if flag & 0x20 else -delta
            elif not flag & 0x20:
                current += _i16(self.data, cursor)
                cursor += 2
            ys.append(current)
        points = [Point(xs[i], ys[i], bool(flags[i] & 0x01)) for i in range(point_count)]
        contours: list[list[Point]] = []
        first = 0
        for endpoint in endpoints:
            contours.append(points[first : endpoint + 1])
            first = endpoint + 1
        return contours

    def _composite_glyph(
        self,
        start: int,
        parent: tuple[float, float, float, float, float, float],
        depth: int,
    ) -> list[list[Point]]:
        cursor = start + 10
        contours: list[list[Point]] = []
        flags = self.MORE_COMPONENTS
        while flags & self.MORE_COMPONENTS:
            flags = _u16(self.data, cursor)
            glyph = _u16(self.data, cursor + 2)
            cursor += 4
            if flags & self.ARG_1_AND_2_ARE_WORDS:
                arg1, arg2 = struct.unpack_from(">hh", self.data, cursor)
                cursor += 4
            else:
                arg1, arg2 = struct.unpack_from(">bb", self.data, cursor)
                cursor += 2
            dx, dy = (arg1, arg2) if flags & self.ARGS_ARE_XY_VALUES else (0, 0)
            xx, xy, yx, yy = 1.0, 0.0, 0.0, 1.0
            if flags & self.WE_HAVE_A_SCALE:
                xx = yy = _f2dot14(self.data, cursor)
                cursor += 2
            elif flags & self.WE_HAVE_AN_X_AND_Y_SCALE:
                xx = _f2dot14(self.data, cursor)
                yy = _f2dot14(self.data, cursor + 2)
                cursor += 4
            elif flags & self.WE_HAVE_A_TWO_BY_TWO:
                xx = _f2dot14(self.data, cursor)
                xy = _f2dot14(self.data, cursor + 2)
                yx = _f2dot14(self.data, cursor + 4)
                yy = _f2dot14(self.data, cursor + 6)
                cursor += 8
            local = (xx, xy, yx, yy, dx, dy)
            combined = self._combine(parent, local)
            contours.extend(self.glyph_contours(glyph, combined, depth + 1))
        if flags & self.WE_HAVE_INSTRUCTIONS:
            instruction_length = _u16(self.data, cursor)
            cursor += 2 + instruction_length
        return contours

    @staticmethod
    def _combine(
        parent: tuple[float, float, float, float, float, float],
        child: tuple[float, float, float, float, float, float],
    ) -> tuple[float, float, float, float, float, float]:
        pxx, pxy, pyx, pyy, pdx, pdy = parent
        cxx, cxy, cyx, cyy, cdx, cdy = child
        return (
            pxx * cxx + pxy * cyx,
            pxx * cxy + pxy * cyy,
            pyx * cxx + pyy * cyx,
            pyx * cxy + pyy * cyy,
            pxx * cdx + pxy * cdy + pdx,
            pyx * cdx + pyy * cdy + pdy,
        )

    @staticmethod
    def _transform_contour(
        contour: Iterable[Point],
        transform: tuple[float, float, float, float, float, float],
    ) -> list[Point]:
        xx, xy, yx, yy, dx, dy = transform
        return [
            Point(xx * point.x + xy * point.y + dx, yx * point.x + yy * point.y + dy, point.on_curve)
            for point in contour
        ]

    @staticmethod
    def _contour_commands(
        contour: list[Point], pen_x: float, baseline: float, scale: float
    ) -> list[str]:
        if not contour:
            return []
        points = contour[:]
        if points[0].on_curve:
            start = points[0]
            sequence = points[1:]
        elif points[-1].on_curve:
            start = points[-1]
            sequence = points[:-1]
        else:
            start = Point(
                (points[-1].x + points[0].x) / 2,
                (points[-1].y + points[0].y) / 2,
                True,
            )
            sequence = points

        def sx(point: Point) -> str:
            return _fmt(pen_x + point.x * scale)

        def sy(point: Point) -> str:
            return _fmt(baseline - point.y * scale)

        commands = [f"M{sx(start)} {sy(start)}"]
        index = 0
        total = len(sequence)
        while index < total:
            point = sequence[index]
            if point.on_curve:
                commands.append(f"L{sx(point)} {sy(point)}")
                index += 1
                continue
            next_point = sequence[(index + 1) % total] if total else start
            if index == total - 1:
                next_point = start
            if next_point.on_curve:
                commands.append(f"Q{sx(point)} {sy(point)} {sx(next_point)} {sy(next_point)}")
                index += 2
            else:
                midpoint = Point(
                    (point.x + next_point.x) / 2,
                    (point.y + next_point.y) / 2,
                    True,
                )
                commands.append(f"Q{sx(point)} {sy(point)} {sx(midpoint)} {sy(midpoint)}")
                index += 1
        commands.append("Z")
        return commands


def text_group(
    font: TrueTypeFont,
    group_id: str,
    text: str,
    x: float,
    baseline: float,
    size: float,
    color: str,
    *,
    anchor: str = "start",
    max_width: float | None = None,
    stroke: float = 0.55,
) -> str:
    if not text:
        return f'<g id="{group_id}" data-empty="true"/>'
    actual_size = size
    width = font.text_width(text, actual_size)
    if max_width is not None and width > max_width:
        actual_size *= max_width / width
        width = max_width
    return (
        f'<text id="{group_id}" data-copy="{html.escape(text, quote=True)}" '
        f'data-width="{_fmt(width)}" x="{_fmt(x)}" y="{_fmt(baseline)}" '
        f'font-family="Noto Sans SC" font-size="{_fmt(actual_size)}" '
        f'text-anchor="{anchor}" fill="{color}" stroke="{color}" '
        f'stroke-width="{_fmt(stroke)}" stroke-linejoin="round">'
        f'{html.escape(text)}</text>'
    )


def rarity_track(rarity: int) -> str:
    filled = max(1, min(3, rarity + 1))
    color = [CYAN, VIOLET, IVORY][max(0, min(2, rarity))]
    shapes = []
    for index in range(3):
        cx = 251 + index * 14
        fill = color if index < filled else "none"
        stroke = color if index < filled else "#5A526F"
        shapes.append(
            f'<path d="M{cx} 20l5 5-5 5-5-5z" fill="{fill}" '
            f'stroke="{stroke}" stroke-width="1.5"/>'
        )
    return '<g id="rarity-track">' + "".join(shapes) + "</g>"


def target_icon(target_type: int) -> str:
    x, y = 198, 165
    common = f'fill="none" stroke="{CYAN}" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"'
    if target_type == 0:
        body = f'<rect x="{x}" y="{y}" width="14" height="14" rx="3" {common}/><circle cx="{x+7}" cy="{y+7}" r="2" fill="{IVORY}"/>'
    elif target_type == 1:
        body = f'<path d="M{x} {y+3}h14M{x+2} {y+3}v10h10V{y+3}M{x+5} {y+7}h4" {common}/>'
    elif target_type == 2:
        body = f'<path d="M{x} {y+2}v12M{x+14} {y+2}v12M{x+3} {y+8}h8" {common}/>'
    elif target_type == 3:
        body = f'<circle cx="{x+7}" cy="{y+7}" r="6" {common}/><path d="M{x+7} {y+1}v12M{x+1} {y+7}h12" {common}/>'
    else:
        body = f'<rect x="{x}" y="{y+2}" width="9" height="9" rx="2" {common}/><rect x="{x+5}" y="{y+5}" width="9" height="9" rx="2" {common}/>'
    return f'<g id="target-icon">{body}</g>'


def artwork(card_id: str) -> str:
    stroke = f'stroke="{CYAN}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"'
    mutation = f'stroke="{VIOLET}" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"'
    die = lambda x, y, dots: (
        f'<rect x="{x}" y="{y}" width="54" height="54" rx="12" fill="#151038" {stroke}/>'
        + "".join(f'<circle cx="{x+dx}" cy="{y+dy}" r="4" fill="{IVORY}"/>' for dx, dy in dots)
    )
    die_patterns = {
        1: [(27, 27)],
        2: [(16, 16), (38, 38)],
        3: [(16, 16), (27, 27), (38, 38)],
        4: [(16, 16), (38, 16), (16, 38), (38, 38)],
        5: [(16, 16), (38, 16), (27, 27), (16, 38), (38, 38)],
        6: [(16, 14), (38, 14), (16, 27), (38, 27), (16, 40), (38, 40)],
    }
    value_die = lambda x, y, value: die(x, y, die_patterns[value])
    if card_id == "starter_nudge_down_1":
        dots4 = [(16, 16), (38, 16), (16, 38), (38, 38)]
        dots3 = [(16, 16), (27, 27), (38, 38)]
        body = die(54, 66, dots4) + die(192, 66, dots3)
        body += f'<path d="M124 88h52m-12-11 12 11-12 11" {mutation}/><path d="M141 108h18" {mutation}/>'
    elif card_id == "starter_nudge_up_1":
        body = value_die(54, 66, 3) + value_die(192, 66, 4)
        body += f'<path d="M124 88h52m-12-11 12 11-12 11" {mutation}/>'
        body += f'<path d="M150 111V99m-6 6h12" {mutation}/>'
    elif card_id == "starter_nudge_down_2":
        body = value_die(54, 66, 5) + value_die(192, 66, 3)
        body += f'<path d="M120 88h56m-12-11 12 11-12 11" {mutation}/>'
        body += f'<path d="M137 108h10M153 108h10" {mutation}/>'
    elif card_id == "starter_nudge_up_2":
        body = value_die(54, 66, 2) + value_die(192, 66, 4)
        body += f'<path d="M120 88h56m-12-11 12 11-12 11" {mutation}/>'
        body += f'<path d="M142 114V102m-6 6h12M158 114V102m-6 6h12" {mutation}/>'
    elif card_id in ("starter_map_1", "starter_map_2"):
        gain = 1 if card_id == "starter_map_1" else 2
        body = f'<path d="M46 116V68h72v48M182 116V68h72v48" {stroke}/>'
        body += f'<path d="M58 68v-8h48v8M194 68v-8h48v8" {mutation}/>'
        body += f'<path d="M68 101V91M82 101V84" {stroke}/>'
        heights = [17, 25] + ([33] if gain == 2 else [])
        for index, height in enumerate(heights):
            x = 204 + index * 14
            body += f'<path d="M{x} 101V{101-height}" {mutation}/>'
        body += f'<path d="M132 88h34m-10-9 10 9-10 9" {mutation}/>'
        if gain == 2:
            body += f'<circle cx="149" cy="110" r="3" fill="{VIOLET}"/><circle cx="160" cy="110" r="3" fill="{VIOLET}"/>'
        else:
            body += f'<circle cx="154" cy="110" r="3" fill="{VIOLET}"/>'
    elif card_id in ("starter_repeat_1", "starter_repeat_2", "shop_triple_repeat"):
        repeat_count = {
            "starter_repeat_1": 1,
            "starter_repeat_2": 2,
            "shop_triple_repeat": 3,
        }[card_id]
        body = f'<path d="M92 115V69h116v46" {stroke}/><path d="M108 69v-9h84v9" {stroke}/>'
        body += f'<path d="M112 104V87M130 104V80M148 104V92" {stroke}/>'
        body += f'<path d="M181 108c28-8 37-34 20-52-13-14-38-15-52-4" {mutation}/>'
        body += f'<path d="M151 42l-2 10 10 2" {mutation}/>'
        echo_start = 196 - (repeat_count - 1) * 14
        for index in range(repeat_count):
            x = echo_start + index * 28
            body += f'<rect x="{x}" y="82" width="22" height="22" rx="5" fill="#151038" stroke="{VIOLET}" stroke-width="3" opacity=".78"/>'
    elif card_id in ("starter_stable_repeat", "starter_amplified_repeat", "shop_amplified_chain", "faceless_compressed_repeat"):
        gain = 0 if card_id in ("starter_stable_repeat", "faceless_compressed_repeat") else (2 if card_id == "shop_amplified_chain" else 1)
        amplified = gain > 0
        body = f'<path d="M48 116V67h204v49" {stroke}/><path d="M65 67v-8h170v8" {stroke}/>'
        bar_heights = [12, 20, 28] if amplified else [28, 20, 12]
        for index, height in enumerate(bar_heights):
            x = 76 + index * 17
            body += f'<path d="M{x} 104V{104-height}" {stroke}/>'
        if gain == 1:
            body += f'<path d="M135 96V80m-8 8h16" {mutation}/>'
        elif gain == 2:
            body += f'<path d="M129 95V81m-7 7h14M145 95V81m-7 7h14" {mutation}/>'
        else:
            body += f'<path d="M127 88h16" {mutation}/>'
        echo_count = 2 if card_id == "faceless_compressed_repeat" else 1
        for index in range(echo_count):
            x = 169 + index * 18
            body += f'<rect x="{x}" y="78" width="34" height="28" rx="6" fill="#151038" stroke="{CYAN}" stroke-width="2.5" opacity="{1 if index == 0 else .68}"/>'
        body += f'<path d="M220 103c17-8 20-28 7-39-12-11-34-8-41 4" {mutation}/><path d="M188 58l-2 10 10 1" {mutation}/>'
    elif card_id == "shop_long_push":
        body = value_die(54, 66, 1) + value_die(192, 66, 4)
        body += f'<path d="M120 88h56m-12-11 12 11-12 11" {mutation}/>'
        body += f'<path d="M134 114V102m-5 6h10M150 114V102m-5 6h10M166 114V102m-5 6h10" {mutation}/>'
    elif card_id == "shop_deep_drop":
        body = value_die(54, 66, 6) + value_die(192, 66, 3)
        body += f'<path d="M120 88h56m-12-11 12 11-12 11" {mutation}/>'
        body += f'<path d="M129 108h10M145 108h10M161 108h10" {mutation}/>'
    elif card_id == "mirror_folded_map":
        body = f'<path d="M150 50v76" stroke="{CYAN}" stroke-opacity=".48" stroke-width="2" stroke-dasharray="5 5"/>'
        body += f'<path d="M150 78l13 13-13 13-13-13z" fill="#151038" stroke="{VIOLET}" stroke-width="3"/>'
        body += f'<path d="M38 116V69h88v47M174 116V69h88v47" {stroke}/>'
        body += f'<path d="M54 69v-8h56v8M190 69v-8h56v8" {mutation}/>'
        body += f'<path d="M63 104V87M80 104V78M97 104V70" {stroke}/>'
        body += f'<path d="M199 104V87M216 104V78" stroke="{VIOLET}" stroke-width="3" stroke-linecap="round" opacity=".72"/>'
        body += f'<circle cx="111" cy="87" r="4" fill="{VIOLET}"/><circle cx="247" cy="87" r="4" fill="{VIOLET}" opacity=".55"/>'
    elif card_id == "mirror_soft_echo":
        body = f'<path d="M150 50v76" stroke="{CYAN}" stroke-opacity=".48" stroke-width="2" stroke-dasharray="5 5"/>'
        body += f'<path d="M150 80l11 11-11 11-11-11z" fill="#151038" stroke="{VIOLET}" stroke-width="3"/>'
        body += f'<path d="M34 114V72h92v42M174 114V72h92v42" {stroke}/>'
        body += f'<path d="M50 101V87M66 101V80M82 101V91M190 101V87M206 101V80M222 101V91" {stroke}/>'
        body += f'<rect x="88" y="80" width="24" height="22" rx="5" fill="#151038" stroke="{VIOLET}" stroke-width="3"/>'
        body += f'<rect x="106" y="84" width="20" height="18" rx="4" fill="#151038" stroke="{VIOLET}" stroke-width="2.5" opacity=".72"/>'
        body += f'<rect x="228" y="82" width="24" height="20" rx="5" fill="#151038" stroke="{VIOLET}" stroke-width="3" opacity=".62"/>'
    elif card_id == "mirror_hinged_bridge":
        body = f'<path d="M150 48v78" stroke="{CYAN}" stroke-opacity=".4" stroke-width="2" stroke-dasharray="5 5"/>'
        body += f'<path d="M44 108V75h62v33M194 108V75h62v33" {stroke}/>'
        body += f'<path d="M75 75C101 51 126 51 150 80C174 51 199 51 225 75" {mutation}/>'
        body += f'<path d="M150 72l9 9-9 9-9-9z" fill="#151038" stroke="{CYAN}" stroke-width="3"/>'
        body += f'<path d="M224 101V85m-8 8h16" {mutation}/>'
        body += f'<path d="M75 119C103 102 126 105 150 124C174 105 197 102 225 119" stroke="{VIOLET}" stroke-width="2" stroke-dasharray="6 5" opacity=".58"/>'
    elif card_id == "mirror_double_exposure":
        body = f'<path d="M150 49v77" stroke="{CYAN}" stroke-opacity=".45" stroke-width="2" stroke-dasharray="5 5"/>'
        body += f'<path d="M36 115V68h94v47M170 115V68h94v47" {stroke}/>'
        body += f'<path d="M54 101V85M70 101V77M86 101V69" {stroke}/>'
        body += f'<rect x="93" y="80" width="25" height="22" rx="5" fill="#151038" stroke="{VIOLET}" stroke-width="3"/>'
        body += f'<path d="M188 101V85M204 101V77" stroke="{VIOLET}" stroke-width="3" stroke-linecap="round" opacity=".68"/>'
        body += f'<path d="M150 78l13 13-13 13-13-13z" fill="#151038" stroke="{VIOLET}" stroke-width="3"/>'
    elif card_id == "mirror_deep_echo":
        body = f'<path d="M150 49v77" stroke="{CYAN}" stroke-opacity=".45" stroke-width="2" stroke-dasharray="5 5"/>'
        body += f'<path d="M34 115V69h96v46M170 115V69h96v46" {stroke}/>'
        body += f'<path d="M52 102V84M68 102V75" {stroke}/>'
        body += f'<rect x="82" y="78" width="23" height="23" rx="5" fill="#151038" stroke="{VIOLET}" stroke-width="3"/>'
        body += f'<rect x="103" y="83" width="21" height="18" rx="4" fill="#151038" stroke="{VIOLET}" stroke-width="2.5" opacity=".72"/>'
        body += f'<rect x="221" y="80" width="25" height="21" rx="5" fill="#151038" stroke="{VIOLET}" stroke-width="3" opacity=".62"/>'
        body += f'<path d="M150 78l13 13-13 13-13-13z" fill="#151038" stroke="{VIOLET}" stroke-width="3"/>'
    elif card_id == "mirror_silver_bridge":
        body = f'<path d="M150 48v78" stroke="{CYAN}" stroke-opacity=".4" stroke-width="2" stroke-dasharray="5 5"/>'
        body += f'<path d="M41 110V78h65v32M194 110V78h65v32" {stroke}/>'
        body += f'<path d="M73 78C100 46 126 49 150 79C174 49 200 46 227 78" {mutation}/>'
        body += f'<path d="M150 70l10 10-10 10-10-10z" fill="#151038" stroke="{CYAN}" stroke-width="3"/>'
        body += f'<rect x="211" y="87" width="25" height="21" rx="5" fill="#151038" stroke="{VIOLET}" stroke-width="3"/>'
        body += f'<path d="M73 120C101 105 126 106 150 124C174 106 199 105 227 120" stroke="{VIOLET}" stroke-width="2" stroke-dasharray="6 5" opacity=".58"/>'
    elif card_id == "shop_precision_map":
        body = f'<path d="M63 118V65h174v53" {stroke}/><path d="M84 65v-9h132v9" {mutation}/>'
        for index, value in enumerate([1, 2, 3]):
            x = 82 + index * 58
            body += f'<rect x="{x}" y="76" width="38" height="38" rx="8" fill="#151038" {stroke}/>'
            body += f'<path d="M{x+10} {104-value*5}V104M{x+19} {99-value*4}V104M{x+28} {94-value*3}V104" {mutation}/>'
        body += f'<path d="M70 124h160" stroke="{CYAN}" stroke-opacity=".3" stroke-width="2"/>'
    elif card_id == "starter_link":
        body = f'<path d="M46 110V82h52v28M124 110V82h52v28M202 110V82h52v28" {stroke}/>'
        body += f'<path d="M72 82C101 45 199 45 228 82" {mutation}/><path d="M222 71l6 11-12-1" {mutation}/>'
        body += f'<circle cx="72" cy="96" r="5" fill="{IVORY}"/><circle cx="150" cy="96" r="5" fill="{VIOLET}"/><circle cx="228" cy="96" r="5" fill="{IVORY}"/>'
    elif card_id in ("starter_reverse", "shop_reverse_backup"):
        body = f'<path d="M57 83C90 51 210 51 243 83" {mutation}/><path d="M232 70l11 13-17-1" {mutation}/>'
        body += f'<path d="M243 107c-33 31-153 31-186 0" {stroke}/><path d="M68 120l-11-13 17 1" {stroke}/>'
        body += f'<path d="M150 77l18 18-18 18-18-18z" fill="#151038" stroke="{CYAN}" stroke-width="3"/><circle cx="150" cy="95" r="5" fill="{VIOLET}"/>'
    elif card_id in ("shop_dice_index", "shop_chain_index"):
        accent = CYAN if card_id == "shop_dice_index" else VIOLET
        body = f'<path d="M75 61h150v66H75zM89 75h122M89 112h122" fill="#151038" stroke="{accent}" stroke-width="3"/>'
        if card_id == "shop_dice_index":
            body += value_die(123, 73, 4)
        else:
            body += f'<path d="M103 101V83h36v18M161 101V83h36v18M139 92h22" {mutation}/>'
        body += f'<path d="M221 76l11 11-11 11-11-11z" fill="{IVORY}" stroke="{accent}" stroke-width="2"/>'
    elif card_id == "faceless_copy_value":
        dots = [(16, 16), (38, 16), (16, 38), (38, 38)]
        body = die(57, 66, dots) + die(189, 66, dots)
        body += f'<path d="M125 88h48m-11-10 11 10-11 10" {mutation}/><path d="M125 108h48" stroke="{VIOLET}" stroke-opacity=".45" stroke-width="2" stroke-dasharray="5 5"/>'
    elif card_id == "faceless_lock_bonus":
        dots = [(16, 14), (38, 14), (16, 27), (38, 27), (16, 40), (38, 40)]
        body = f'<circle cx="150" cy="93" r="52" stroke="{VIOLET}" stroke-opacity=".45" stroke-width="3"/><circle cx="150" cy="93" r="43" stroke="{CYAN}" stroke-width="2" stroke-dasharray="7 6"/>'
        body += die(123, 66, dots)
        body += f'<path d="M113 75V57h18M187 75V57h-18M113 111v18h18M187 111v18h-18" {mutation}/>'
    elif card_id == "faceless_swap_values":
        body = value_die(48, 67, 2) + value_die(198, 67, 5)
        body += f'<path d="M111 77C131 55 169 55 189 77" {mutation}/><path d="M181 64l8 13-15-2" {mutation}/>'
        body += f'<path d="M189 111c-20 22-58 22-78 0" {stroke}/><path d="M119 124l-8-13 15 2" {stroke}/>'
    elif card_id == "faceless_flip_value":
        body = value_die(49, 67, 2) + value_die(197, 67, 5)
        body += f'<path d="M119 91c10-31 52-43 77-18" {mutation}/><path d="M189 60l7 13-15-1" {mutation}/>'
        body += f'<path d="M181 112c-20 18-52 14-66-8" {stroke}/><path d="M126 107l-11-3 2 12" {stroke}/>'
        body += f'<path d="M150 67v51" stroke="{CYAN}" stroke-opacity=".35" stroke-width="2" stroke-dasharray="5 5"/>'
    elif card_id == "faceless_refund_calibration":
        body = f'<path d="M77 105l22-38h44l22 38-22 19H99z" fill="#151038" {stroke}/>'
        body += f'<path d="M157 105l22-38h44l22 38-22 19h-44z" fill="#151038" stroke="{CYAN}" stroke-opacity=".42" stroke-width="3"/>'
        body += f'<circle cx="121" cy="95" r="9" fill="{IVORY}"/><circle cx="201" cy="95" r="9" fill="none" stroke="{VIOLET}" stroke-width="3"/>'
        body += f'<path d="M202 61c-17-18-48-20-68-5" {mutation}/><path d="M137 46l-3 10 11 1" {mutation}/>'
        body += f'<path d="M201 95h-10m5-5v10" {mutation}/>'
    elif card_id == "faceless_exact_tolerance":
        body = f'<path d="M62 101h176" {stroke}/>'
        body += f'<path d="M92 84v34M150 72v58M208 84v34" stroke="{CYAN}" stroke-width="3" stroke-linecap="round"/>'
        body += f'<circle cx="150" cy="101" r="24" fill="#151038" stroke="{VIOLET}" stroke-width="3"/>'
        body += f'<circle cx="150" cy="101" r="8" fill="{IVORY}"/>'
        body += f'<path d="M92 78c15-20 38-30 58-30s43 10 58 30" stroke="{VIOLET}" stroke-width="3" stroke-linecap="round"/>'
        body += f'<circle cx="92" cy="101" r="7" fill="none" stroke="{VIOLET}" stroke-width="3"/><circle cx="208" cy="101" r="7" fill="none" stroke="{VIOLET}" stroke-width="3"/>'
    elif card_id == "faceless_even_tolerance":
        body = f'<path d="M47 118h206M58 110V72h38v38M108 110V72h38v38M158 110V72h38v38M208 110V72h38v38" {stroke}/>'
        body += f'<circle cx="70" cy="88" r="4" fill="{IVORY}"/><circle cx="84" cy="96" r="4" fill="{IVORY}"/>'
        body += f'<circle cx="118" cy="84" r="4" fill="{IVORY}"/><circle cx="136" cy="84" r="4" fill="{IVORY}"/><circle cx="118" cy="100" r="4" fill="{IVORY}"/><circle cx="136" cy="100" r="4" fill="{IVORY}"/>'
        body += f'<circle cx="177" cy="92" r="7" fill="{VIOLET}"/><path d="M158 72h38v38h-38z" fill="none" stroke="{VIOLET}" stroke-width="4"/>'
        body += f'<circle cx="218" cy="82" r="3.5" fill="{IVORY}"/><circle cx="236" cy="82" r="3.5" fill="{IVORY}"/><circle cx="218" cy="92" r="3.5" fill="{IVORY}"/><circle cx="236" cy="92" r="3.5" fill="{IVORY}"/><circle cx="218" cy="102" r="3.5" fill="{IVORY}"/><circle cx="236" cy="102" r="3.5" fill="{IVORY}"/>'
        body += f'<path d="M151 61c12-12 39-12 51 0" {mutation}/>'
    elif card_id == "faceless_sequence_tolerance":
        body = f'<path d="M49 101h202" {stroke}/>'
        for x, height in [(62, 18), (108, 28), (192, 43), (238, 53)]:
            body += f'<circle cx="{x}" cy="101" r="10" fill="#151038" stroke="{CYAN}" stroke-width="3"/><path d="M{x} 91V{91-height}" stroke="{CYAN}" stroke-width="3" stroke-linecap="round"/>'
        body += f'<path d="M119 83C139 61 161 61 181 83" stroke="{VIOLET}" stroke-width="4" stroke-linecap="round" stroke-dasharray="7 5"/>'
        body += f'<path d="M172 72l9 11-14-1" {mutation}/><circle cx="150" cy="66" r="6" fill="{VIOLET}"/>'
    elif card_id == "faceless_table_receipt":
        body = f'<path d="M40 113V67h94v46M56 67v-8h62v8" {stroke}/>'
        body += f'<path d="M65 91l12 12 28-31" {mutation}/>'
        body += f'<path d="M146 90h27m-9-9 9 9-9 9" {stroke}/>'
        body += f'<path d="M188 58h64v68h-64zM198 70h44M198 114h44" fill="#151038" stroke="{VIOLET}" stroke-width="3"/>'
        body += f'<path d="M220 80l10 10-10 10-10-10z" fill="{IVORY}" stroke="{CYAN}" stroke-width="2"/>'
    elif card_id == "faceless_full_allocation":
        body = ""
        for index in range(6):
            x = 38 + (index % 3) * 34
            y = 64 + (index // 3) * 34
            body += f'<rect x="{x}" y="{y}" width="26" height="26" rx="6" fill="#151038" stroke="{CYAN}" stroke-width="2.5"/><circle cx="{x+13}" cy="{y+13}" r="4" fill="{IVORY}"/>'
        body += f'<path d="M144 91h28m-9-9 9 9-9 9" {mutation}/>'
        body += f'<path d="M188 58h66v68h-66zM198 70h46M198 114h46" fill="#151038" stroke="{VIOLET}" stroke-width="3"/>'
        body += f'<path d="M213 80l9 9-9 9-9-9zM232 80l9 9-9 9-9-9z" fill="{IVORY}" stroke="{CYAN}" stroke-width="2"/>'
    elif card_id == "faceless_three_seats":
        body = ""
        for index in range(3):
            x = 35 + index * 61
            body += f'<path d="M{x} 109V72h48v37" {stroke}/><circle cx="{x+24}" cy="91" r="7" fill="{IVORY}"/>'
        body += f'<path d="M226 56h48v70h-48zM235 68h30M235 114h30" fill="#151038" stroke="{VIOLET}" stroke-width="3"/>'
        body += f'<path d="M240 82l8 8-8 8-8-8zM259 82l8 8-8 8-8-8z" fill="{IVORY}" stroke="{CYAN}" stroke-width="2"/>'
        body += f'<path d="M208 91h15m-7-7 7 7-7 7" {mutation}/>'
    elif card_id == "faceless_complete_dossier":
        body = ""
        for index in range(3):
            x = 31 + index * 54
            body += f'<path d="M{x} 108V72h42v36" {stroke}/><path d="M{x+9} 90l8 8 16-20" {mutation}/>'
        body += f'<path d="M191 54h76v74h-76zM202 68h54M202 115h54" fill="#151038" stroke="{VIOLET}" stroke-width="3"/>'
        body += f'<path d="M210 82l8 8-8 8-8-8zM229 82l8 8-8 8-8-8zM248 82l8 8-8 8-8-8z" fill="{IVORY}" stroke="{CYAN}" stroke-width="2"/>'
        body += f'<path d="M178 91h10m-6-6 6 6-6 6" {mutation}/>'
    elif card_id == "faceless_strict_mapping":
        body = f'<path d="M37 116V68h226v48M55 68v-8h190v8" {stroke}/>'
        for index in range(5):
            x = 55 + index * 39
            color = VIOLET if index == 4 else CYAN
            body += f'<rect x="{x}" y="82" width="28" height="26" rx="6" fill="#151038" stroke="{color}" stroke-width="3"/>'
        body += f'<path d="M223 98V80m10 18V72" {mutation}/>'
        body += f'<path d="M247 93V79m-7 7h14M247 112V100m-7 6h14" {mutation}/>'
        body += f'<path d="M199 76l8 8-8 8-8-8z" fill="{VIOLET}"/>'
    elif card_id == "faceless_reverse_replay":
        body = f'<path d="M51 79C86 49 214 49 249 79" {mutation}/><path d="M237 67l12 12-17 0" {mutation}/>'
        body += f'<path d="M249 111c-35 29-163 29-198 0" {stroke}/><path d="M63 123l-12-12 17 0" {stroke}/>'
        for index in range(3):
            x = 73 + index * 65
            body += f'<path d="M{x} 108V82h43v26" stroke="{CYAN}" stroke-width="2.5"/>'
        body += f'<rect x="211" y="84" width="25" height="22" rx="5" fill="#151038" stroke="{VIOLET}" stroke-width="3"/>'
    elif card_id == "faceless_closed_circuit":
        body = ""
        for index in range(3):
            x = 45 + index * 83
            body += f'<path d="M{x} 108V78h52v30" {stroke}/><circle cx="{x+26}" cy="94" r="5" fill="{IVORY}"/>'
        body += f'<path d="M71 78C103 43 197 43 229 78M229 108c-32 32-126 32-158 0" {mutation}/>'
        body += f'<path d="M219 65l10 13-16-1M81 121l-10-13 16 1" {mutation}/>'
        body += f'<rect x="211" y="83" width="29" height="23" rx="5" fill="#151038" stroke="{VIOLET}" stroke-width="3"/>'
    elif card_id == "stage7_fault_die":
        body = value_die(123, 66, 1)
        body += f'<path d="M113 75V57h18M187 75V57h-18M113 111v18h18M187 111v18h-18" {mutation}/>'
        body += f'<path d="M121 61l58 64M179 61l-58 64" stroke="#FF5C8A" stroke-width="3.5" stroke-linecap="round"/>'
    elif card_id == "stage7_all_in":
        body = f'<path d="M150 52l52 35-52 35-52-35z" fill="#151038" stroke="#FFB547" stroke-width="3"/>'
        body += f'<circle cx="150" cy="87" r="11" fill="#FF5C8A"/>'
        body += f'<path d="M52 119h196M64 111l22-13M236 111l-22-13" stroke="#FFB547" stroke-width="4" stroke-linecap="round"/>'
    elif card_id == "stage7_insurance_draft":
        body = f'<path d="M108 52h68l16 16v61h-84z" fill="#151038" stroke="#FF5C8A" stroke-width="3"/>'
        body += f'<path d="M176 52v16h16M122 81h56M122 96h48M122 111h37" stroke="{IVORY}" stroke-width="3" stroke-linecap="round"/>'
        body += f'<path d="M90 120l35-35" stroke="{CYAN}" stroke-width="5" stroke-linecap="round"/>'
    elif card_id == "stage7_burned_rewrite":
        body = f'<path d="M87 67h79v57H87zM132 52h81v58h-81z" fill="#151038" stroke="#8EA7FF" stroke-width="3"/>'
        body += f'<path d="M147 69h51M147 84h41M147 99h31" stroke="{IVORY}" stroke-width="3" stroke-linecap="round"/>'
        body += f'<path d="M103 129c18-28 31-13 40-40 7 29 29 25 18 48" fill="#FF5C8A" opacity=".9"/>'
    else:
        raise ValueError(f"missing artwork grammar for {card_id}")
    return f'<g id="effect-artwork">{body}</g>'


def generate_svg(card: dict[str, object], font: TrueTypeFont) -> str:
    rarity = int(card["rarity"])
    identity = str(card["identity"])
    border = [CYAN, VIOLET, VIOLET][rarity]
    border_width = [2.5, 3, 4][rarity]
    metadata = html.escape(json.dumps(card, ensure_ascii=False, sort_keys=True))
    lines = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="300" height="200" viewBox="0 0 300 200" fill="none" '
        f'data-card-id="{html.escape(str(card["id"]))}" data-card-face="complete-v1">',
        f'<metadata>{metadata}</metadata>',
        f'<rect x="5" y="5" width="290" height="190" rx="18" fill="{GLASS}" fill-opacity=".96" stroke="{border}" stroke-width="{border_width}"/>',
        f'<path d="M5 38V5h33M262 195h33v-33" stroke="{IVORY if rarity == 2 else VIOLET}" stroke-width="2.5" stroke-linecap="round"/>',
        f'<path d="M16 44h268" stroke="{CYAN}" stroke-opacity=".26" stroke-width="1.5"/>',
        f'<rect x="14" y="137" width="272" height="48" rx="10" fill="{DEEP}" fill-opacity=".92" stroke="{CYAN}" stroke-opacity=".28"/>',
        text_group(
            font,
            "card-identity",
            identity,
            18,
            32,
            16,
            identity_color(identity),
            max_width=38,
            stroke=0.65,
        ),
        text_group(font, "card-name", str(card["name"]), 58, 34, 22, IVORY, max_width=162, stroke=0.8),
        rarity_track(rarity),
        artwork(str(card["id"])),
        text_group(font, "effect-summary", str(card["effect"]), 22, 158, 20.5, IVORY, max_width=152, stroke=0.72),
        text_group(font, "effect-detail", str(card["detail"]), 22, 179, 14.5, MUTED, max_width=160, stroke=0.45),
        target_icon(int(card["target_type"])),
        text_group(font, "target-copy", str(card["target"]), 280, 178, 14, CYAN, anchor="end", max_width=66, stroke=0.45),
        '</svg>\n',
    ]
    return "\n  ".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--font", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    payload = json.loads(args.manifest.read_text(encoding="utf-8"))
    if payload.get("schema") != "project-joker.card-face-manifest.v1":
        raise ValueError("unsupported card-face manifest schema")
    font = TrueTypeFont(args.font)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    generated = []
    for card in payload["cards"]:
        output = args.output_dir / f'{card["id"]}.svg.txt'
        output.write_text(generate_svg(card, font), encoding="utf-8", newline="\n")
        generated.append(output.name)
    print(f"GENERATED {len(generated)} editable card-face SVG sources")
    print(f"FONT {args.font.name} sha256={font.sha256}")
    for name in generated:
        print(f"  {name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
