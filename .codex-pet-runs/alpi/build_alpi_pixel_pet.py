#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw


RUN_DIR = Path(__file__).resolve().parent
FRAMES = RUN_DIR / "frames"
DECODED = RUN_DIR / "decoded"

CELL_W = 192
CELL_H = 208
LOW = 64
SCALE = 3

ROWS = [
    ("idle", 6),
    ("running-right", 8),
    ("running-left", 8),
    ("waving", 4),
    ("jumping", 5),
    ("failed", 8),
    ("waiting", 6),
    ("running", 6),
    ("review", 6),
]

OUTLINE = "#3a2a22"
WOOL = "#f4eedc"
WOOL_2 = "#ded2b4"
WOOL_3 = "#fff8e8"
FACE = "#c9935d"
FACE_2 = "#b87948"
EAR_INNER = "#d7a17e"
EYE = "#191512"
SCARF = "#158b8c"
SCARF_DARK = "#0d5c61"
SCARF_LIGHT = "#67c7bd"
HOOF = "#4b3528"
BLUSH = "#e3a28a"
TEAR = "#5fb7d5"


def rect(draw: ImageDraw.ImageDraw, box, fill, outline=OUTLINE, width=1) -> None:
    x0, y0, x1, y1 = box
    draw.rectangle((x0 - width, y0 - width, x1 + width, y1 + width), fill=outline)
    draw.rectangle(box, fill=fill)


def ellipse(draw: ImageDraw.ImageDraw, box, fill, outline=OUTLINE, width=1) -> None:
    x0, y0, x1, y1 = box
    draw.ellipse((x0 - width, y0 - width, x1 + width, y1 + width), fill=outline)
    draw.ellipse(box, fill=fill)


def poly(draw: ImageDraw.ImageDraw, points, fill, outline=OUTLINE, width=1) -> None:
    draw.polygon(points, fill=fill)
    draw.line(points + [points[0]], fill=outline, width=width, joint="curve")


def maybe_flip(image: Image.Image, direction: int) -> Image.Image:
    return image.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if direction < 0 else image


def draw_front(
    *,
    body_y: int = 0,
    head_x: int = 0,
    head_y: int = 0,
    blink: bool = False,
    wave: int = 0,
    jump: int = 0,
    sad: bool = False,
    waiting: int = 0,
    review: int = 0,
    work: int = 0,
) -> Image.Image:
    img = Image.new("RGBA", (LOW, LOW), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    oy = body_y + jump

    # Back legs.
    leg_lift = 1 if jump < 0 else 0
    rect(d, (21, 45 + oy - leg_lift, 26, 56 + oy), WOOL)
    rect(d, (38, 45 + oy - leg_lift, 43, 56 + oy), WOOL)
    rect(d, (20, 55 + oy, 27, 58 + oy), HOOF)
    rect(d, (37, 55 + oy, 44, 58 + oy), HOOF)

    # Wool body.
    ellipse(d, (15, 30 + oy, 49, 53 + oy), WOOL)
    for box in (
        (13, 34 + oy, 25, 48 + oy),
        (23, 28 + oy, 36, 43 + oy),
        (37, 34 + oy, 51, 49 + oy),
        (21, 41 + oy, 43, 56 + oy),
    ):
        ellipse(d, box, WOOL if box[1] != 28 + oy else WOOL_3, width=1)
    d.rectangle((19, 46 + oy, 45, 52 + oy), fill=WOOL)

    # Neck.
    ellipse(d, (25, 18 + oy, 39, 43 + oy), WOOL_2)
    rect(d, (28, 21 + oy, 36, 43 + oy), WOOL)

    # Ears and head.
    hx = head_x
    hy = head_y + oy
    poly(d, [(23 + hx, 13 + hy), (25 + hx, 2 + hy), (31 + hx, 14 + hy)], WOOL)
    poly(d, [(41 + hx, 13 + hy), (39 + hx, 2 + hy), (33 + hx, 14 + hy)], WOOL)
    poly(d, [(25 + hx, 11 + hy), (26 + hx, 5 + hy), (29 + hx, 12 + hy)], EAR_INNER)
    poly(d, [(39 + hx, 11 + hy), (38 + hx, 5 + hy), (35 + hx, 12 + hy)], EAR_INNER)
    ellipse(d, (21 + hx, 11 + hy, 43 + hx, 31 + hy), WOOL)
    ellipse(d, (26 + hx, 16 + hy, 38 + hx, 30 + hy), FACE)

    # Face.
    if blink:
        d.rectangle((27 + hx, 21 + hy, 30 + hx, 22 + hy), fill=EYE)
        d.rectangle((34 + hx, 21 + hy, 37 + hx, 22 + hy), fill=EYE)
    elif sad:
        d.rectangle((27 + hx, 22 + hy, 29 + hx, 24 + hy), fill=EYE)
        d.rectangle((35 + hx, 22 + hy, 37 + hx, 24 + hy), fill=EYE)
        d.point((29 + hx, 25 + hy), fill=TEAR)
    else:
        d.rectangle((27 + hx, 20 + hy, 29 + hx, 23 + hy), fill=EYE)
        d.rectangle((35 + hx, 20 + hy, 37 + hx, 23 + hy), fill=EYE)
        d.point((28 + hx, 20 + hy), fill=WOOL_3)
        d.point((36 + hx, 20 + hy), fill=WOOL_3)
    if sad:
        d.rectangle((31 + hx, 27 + hy, 34 + hx, 27 + hy), fill=EYE)
        d.point((30 + hx, 28 + hy), fill=EYE)
        d.point((35 + hx, 28 + hy), fill=EYE)
    else:
        d.rectangle((31 + hx, 26 + hy, 33 + hx, 26 + hy), fill=EYE)
        d.point((30 + hx, 25 + hy), fill=EYE)
        d.point((34 + hx, 25 + hy), fill=EYE)
    d.point((25 + hx, 25 + hy), fill=BLUSH)
    d.point((39 + hx, 25 + hy), fill=BLUSH)

    # Scarf.
    scarf_shift = work % 2
    poly(d, [(22, 36 + oy), (42, 36 + oy), (39, 42 + oy), (25, 42 + oy)], SCARF, width=1)
    rect(d, (30, 38 + oy, 34, 43 + oy), SCARF_LIGHT)
    poly(d, [(34, 40 + oy), (47 + scarf_shift, 43 + oy), (36, 46 + oy)], SCARF_DARK)

    # Front legs, one can wave or ask.
    if wave:
        raised = max(0, min(3, wave))
        rect(d, (15, 31 + oy - raised * 2, 20, 44 + oy - raised * 3), WOOL)
        rect(d, (14, 29 + oy - raised * 3, 20, 33 + oy - raised * 3), HOOF)
    elif waiting:
        rect(d, (18, 37 + oy - waiting, 23, 46 + oy - waiting), WOOL)
        rect(d, (17, 35 + oy - waiting, 23, 39 + oy - waiting), HOOF)
    else:
        rect(d, (17, 42 + oy, 22, 55 + oy), WOOL)
        rect(d, (16, 54 + oy, 23, 57 + oy), HOOF)
    rect(d, (42, 42 + oy, 47, 55 + oy), WOOL)
    rect(d, (41, 54 + oy, 48, 57 + oy), HOOF)

    if review:
        d.rectangle((27 + hx, 19 + hy, 30 + hx, 20 + hy), fill=EYE)
        d.rectangle((34 + hx, 19 + hy, 37 + hx, 20 + hy), fill=EYE)

    return img


def draw_side(*, direction: int = 1, step: int = 0, bob: int = 0) -> Image.Image:
    img = Image.new("RGBA", (LOW, LOW), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    oy = bob

    # Side body and legs.
    leg_a = 2 if step % 2 == 0 else -1
    leg_b = -1 if step % 2 == 0 else 2
    rect(d, (20, 43 + oy + leg_a, 25, 56 + oy + leg_a), WOOL)
    rect(d, (37, 43 + oy + leg_b, 42, 56 + oy + leg_b), WOOL)
    rect(d, (19, 55 + oy + leg_a, 26, 58 + oy + leg_a), HOOF)
    rect(d, (36, 55 + oy + leg_b, 43, 58 + oy + leg_b), HOOF)
    ellipse(d, (16, 31 + oy, 45, 53 + oy), WOOL)
    ellipse(d, (13, 35 + oy, 25, 48 + oy), WOOL_3)
    ellipse(d, (35, 34 + oy, 49, 50 + oy), WOOL)

    # Neck and profile head face right, then mirror if needed.
    ellipse(d, (30, 18 + oy, 42, 42 + oy), WOOL_2)
    rect(d, (33, 22 + oy, 39, 42 + oy), WOOL)
    poly(d, [(34, 13 + oy), (36, 3 + oy), (41, 14 + oy)], WOOL)
    poly(d, [(45, 15 + oy), (44, 5 + oy), (39, 15 + oy)], WOOL)
    ellipse(d, (31, 12 + oy, 51, 30 + oy), WOOL)
    ellipse(d, (40, 17 + oy, 53, 29 + oy), FACE)
    d.rectangle((45, 20 + oy, 47, 23 + oy), fill=EYE)
    d.point((46, 20 + oy), fill=WOOL_3)
    d.rectangle((49, 26 + oy, 51, 26 + oy), fill=EYE)

    # Scarf trailing opposite the movement direction.
    poly(d, [(27, 36 + oy), (44, 36 + oy), (42, 42 + oy), (29, 42 + oy)], SCARF, width=1)
    trail = 1 if step % 2 else 0
    poly(d, [(27, 39 + oy), (13 - trail, 42 + oy), (27, 46 + oy)], SCARF_DARK)

    return maybe_flip(img, direction)


def upscale(logical: Image.Image) -> Image.Image:
    scaled = logical.resize((LOW * SCALE, LOW * SCALE), Image.Resampling.NEAREST)
    cell = Image.new("RGBA", (CELL_W, CELL_H), (0, 0, 0, 0))
    cell.alpha_composite(scaled, (0, 8))
    return cell


def save_state(state: str, frames: list[Image.Image]) -> None:
    state_dir = FRAMES / state
    state_dir.mkdir(parents=True, exist_ok=True)
    for index, frame in enumerate(frames):
        frame.save(state_dir / f"{index:02d}.png")


def main() -> None:
    FRAMES.mkdir(parents=True, exist_ok=True)
    DECODED.mkdir(parents=True, exist_ok=True)

    idle = [
        upscale(draw_front(body_y=y, blink=(i == 2)))
        for i, y in enumerate([0, 0, -1, -1, 0, 0])
    ]
    save_state("idle", idle)

    right = [upscale(draw_side(direction=1, step=i, bob=[0, -1, 0, 1, 0, -1, 0, 1][i])) for i in range(8)]
    left = [upscale(draw_side(direction=-1, step=i, bob=[0, -1, 0, 1, 0, -1, 0, 1][i])) for i in range(8)]
    save_state("running-right", right)
    save_state("running-left", left)

    save_state("waving", [upscale(draw_front(wave=w, body_y=0)) for w in [0, 2, 3, 1]])
    save_state("jumping", [upscale(draw_front(jump=j)) for j in [0, -3, -6, -3, 0]])
    save_state("failed", [upscale(draw_front(sad=True, body_y=y, head_y=1)) for y in [0, 1, 1, 0, 1, 1, 0, 0]])
    save_state("waiting", [upscale(draw_front(waiting=w, head_y=h)) for w, h in [(1, 0), (2, -1), (3, -1), (2, 0), (1, 0), (0, 0)]])
    save_state("running", [upscale(draw_front(work=i, body_y=[0, -1, 0, 0, -1, 0][i], review=1)) for i in range(6)])
    save_state("review", [upscale(draw_front(review=1, head_x=x, blink=(i == 3))) for i, x in enumerate([0, 1, 1, 0, -1, 0])])

    # Base/reference frame for the run folder.
    idle[0].save(DECODED / "base.png")
    (RUN_DIR / "references").mkdir(exist_ok=True)
    idle[0].save(RUN_DIR / "references" / "canonical-base.png")

    manifest = {
        "ok": True,
        "source": "programmatic pixel art for exact Codex pet atlas geometry",
        "cell_width": CELL_W,
        "cell_height": CELL_H,
        "chroma_key": {"hex": "#00ff00", "rgb": [0, 255, 0]},
        "rows": [
            {"state": state, "frames": count, "method": "components"}
            for state, count in ROWS
        ],
    }
    (FRAMES / "frames-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    print(json.dumps({"ok": True, "frames_root": str(FRAMES), "base": str(DECODED / "base.png")}, indent=2))


if __name__ == "__main__":
    main()
