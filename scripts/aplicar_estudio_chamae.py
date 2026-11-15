"""Padroniza fotos de produtos do catalogo Chamae Delivery em 1000x1000 px (1:1).

Pipeline:
1. Carrega cada foto da pasta de entrada (.png, .jpg, .jpeg, .webp).
2. Remove o fundo original (usa ``rembg`` quando disponivel; fallback por
   amostragem de cantos com suavizacao de borda quando ausente).
3. Recorta a area util do produto e redimensiona para a zona segura
   (65% a 72% da altura do canvas de 1000x1000 px).
4. Centraliza sobre o template oficial ``assets/studio/pedestal_chamae_1000.png``
   com sombra suave de contato.
5. Exporta em ``.webp`` e ``.jpg`` (1000x1000 px, <= 180 KB por arquivo).
"""

from __future__ import annotations

import argparse
from io import BytesIO
from pathlib import Path
import sys
from typing import Iterable, Tuple

try:
    from PIL import Image, ImageDraw, ImageFilter
except ImportError as exc:  # pragma: no cover - dependencia externa
    raise SystemExit(
        "Pillow e obrigatorio. Instale com: pip install pillow"
    ) from exc

CANVAS_SIZE = 1000
MIN_HEIGHT_RATIO = 0.65
MAX_HEIGHT_RATIO = 0.72
DEFAULT_HEIGHT_RATIO = 0.68
MAX_WIDTH_RATIO = 0.78
DEFAULT_MAX_KB = 180
FALLBACK_BG_RGB = (0xF6, 0xF1, 0xE7)  # #F6F1E7
SUPPORTED_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}
DEFAULT_TEMPLATE = Path("assets/studio/pedestal_chamae_1000.png")


def remove_background(image: Image.Image, threshold: int = 28) -> Image.Image:
    """Remove o fundo preservando alpha quando ja existir transparencia."""
    rgba = image.convert("RGBA")

    # Tenta remover com rembg (U2-Net) se estiver instalado no ambiente.
    try:
        from rembg import remove as rembg_remove  # type: ignore

        buf = BytesIO()
        rgba.save(buf, format="PNG")
        cut_bytes = rembg_remove(buf.getvalue())
        return Image.open(BytesIO(cut_bytes)).convert("RGBA")
    except ImportError:
        pass

    # Se a imagem ja possui canal alpha util, preserva-o.
    alpha_extrema = rgba.getchannel("A").getextrema()
    if alpha_extrema[0] < 250:
        return rgba

    # Fallback deterministico: amostra cor de fundo nos quatro cantos.
    width, height = rgba.size
    pixels = rgba.load()
    corners = [
        pixels[0, 0][:3],
        pixels[width - 1, 0][:3],
        pixels[0, height - 1][:3],
        pixels[width - 1, height - 1][:3],
    ]
    bg_r = sum(c[0] for c in corners) // 4
    bg_g = sum(c[1] for c in corners) // 4
    bg_b = sum(c[2] for c in corners) // 4

    soft_band = max(12, threshold // 2)
    out = rgba.copy()
    out_px = out.load()
    for y in range(height):
        for x in range(width):
            r, g, b, a = out_px[x, y]
            dist = max(abs(r - bg_r), abs(g - bg_g), abs(b - bg_b))
            if dist <= threshold:
                out_px[x, y] = (r, g, b, 0)
            elif dist < threshold + soft_band:
                factor = (dist - threshold) / soft_band
                out_px[x, y] = (r, g, b, int(a * factor))
    return out


def trim_to_subject(rgba: Image.Image) -> Image.Image:
    """Recorta o bounding box nao transparente da imagem."""
    alpha = rgba.getchannel("A")
    bbox = alpha.point(lambda p: 255 if p > 12 else 0).getbbox()
    if bbox is None:
        return rgba
    return rgba.crop(bbox)


def fit_in_safe_zone(
    subject: Image.Image,
    height_ratio: float,
) -> Image.Image:
    """Redimensiona o produto para 65%-72% da altura sem exceder largura segura."""
    clamped_ratio = max(MIN_HEIGHT_RATIO, min(MAX_HEIGHT_RATIO, height_ratio))
    target_h = int(round(CANVAS_SIZE * clamped_ratio))
    max_w = int(round(CANVAS_SIZE * MAX_WIDTH_RATIO))

    src_w, src_h = subject.size
    if src_w == 0 or src_h == 0:
        return subject

    scale = target_h / src_h
    if src_w * scale > max_w:
        scale = max_w / src_w

    new_w = max(1, int(round(src_w * scale)))
    new_h = max(1, int(round(src_h * scale)))
    return subject.resize((new_w, new_h), Image.Resampling.LANCZOS)


def build_contact_shadow(
    subject_size: Tuple[int, int],
    paste_x: int,
    paste_y: int,
) -> Image.Image:
    """Cria sombra eliptica suave de contato sob a base do produto."""
    subj_w, subj_h = subject_size
    layer = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    shadow_w = max(40, int(subj_w * 0.72))
    shadow_h = max(14, int(subj_h * 0.055))
    cx = paste_x + subj_w // 2
    base_y = paste_y + subj_h - max(2, shadow_h // 5)

    left = cx - shadow_w // 2
    top = base_y - shadow_h // 2
    right = cx + shadow_w // 2
    bottom = base_y + shadow_h // 2

    draw.ellipse((left, top, right, bottom), fill=(26, 18, 8, 88))
    return layer.filter(ImageFilter.GaussianBlur(radius=14))


def compose_on_template(
    subject: Image.Image,
    template: Image.Image,
    height_ratio: float,
) -> Image.Image:
    """Centraliza o produto com sombra suave sobre o pedestal 1000x1000."""
    fitted = fit_in_safe_zone(subject, height_ratio)
    subj_w, subj_h = fitted.size

    paste_x = (CANVAS_SIZE - subj_w) // 2
    # Centraliza verticalmente com leve ancoragem na base do pedestal (52% centro).
    paste_y = max(
        int(CANVAS_SIZE * 0.08),
        min(
            CANVAS_SIZE - subj_h - int(CANVAS_SIZE * 0.10),
            (CANVAS_SIZE - subj_h) // 2,
        ),
    )

    canvas = template.convert("RGBA").resize(
        (CANVAS_SIZE, CANVAS_SIZE), Image.Resampling.LANCZOS
    )
    shadow = build_contact_shadow(fitted.size, paste_x, paste_y)
    canvas = Image.alpha_composite(canvas, shadow)
    canvas.alpha_composite(fitted, dest=(paste_x, paste_y))
    return canvas


def save_within_size_limit(
    image: Image.Image,
    destination: Path,
    fmt: str,
    max_bytes: int,
) -> int:
    """Exporta em WEBP ou JPEG reduzindo qualidade ate respeitar o limite."""
    rgb = Image.new("RGB", image.size, FALLBACK_BG_RGB)
    rgb.paste(image, mask=image.getchannel("A"))

    for quality in (92, 88, 84, 80, 75, 70, 65, 58, 50, 42):
        buf = BytesIO()
        if fmt == "WEBP":
            rgb.save(buf, format="WEBP", quality=quality, method=6)
        else:
            rgb.save(
                buf,
                format="JPEG",
                quality=quality,
                optimize=True,
                progressive=True,
            )
        payload = buf.getvalue()
        if len(payload) <= max_bytes or quality == 42:
            destination.write_bytes(payload)
            return len(payload)
    return 0


def iter_input_images(input_dir: Path) -> Iterable[Path]:
    for path in sorted(input_dir.iterdir()):
        if path.is_file() and path.suffix.lower() in SUPPORTED_EXTENSIONS:
            yield path


def process_directory(
    input_dir: Path,
    output_dir: Path,
    template_path: Path,
    height_ratio: float,
    max_kb: int,
    bg_threshold: int,
) -> int:
    if not input_dir.is_dir():
        raise FileNotFoundError(f"Pasta de entrada nao encontrada: {input_dir}")
    if not template_path.is_file():
        raise FileNotFoundError(
            f"Template oficial nao encontrado: {template_path}. "
            "Posicione o pedestal 1000x1000 em assets/studio/pedestal_chamae_1000.png."
        )

    output_dir.mkdir(parents=True, exist_ok=True)
    template = Image.open(template_path).convert("RGBA")
    max_bytes = max_kb * 1024

    processed = 0
    for src_path in iter_input_images(input_dir):
        with Image.open(src_path) as raw:
            cutout = remove_background(raw, threshold=bg_threshold)
        subject = trim_to_subject(cutout)
        composed = compose_on_template(subject, template, height_ratio)

        stem = src_path.stem
        webp_size = save_within_size_limit(
            composed, output_dir / f"{stem}.webp", "WEBP", max_bytes
        )
        jpg_size = save_within_size_limit(
            composed, output_dir / f"{stem}.jpg", "JPEG", max_bytes
        )
        processed += 1
        print(
            f"[OK] {src_path.name} -> {stem}.webp ({webp_size // 1024} KB), "
            f"{stem}.jpg ({jpg_size // 1024} KB)"
        )

    return processed


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Aplica o estudio Chamae 1:1 (1000x1000) em lote."
    )
    parser.add_argument(
        "input_dir",
        type=Path,
        help="Pasta contendo as fotos originais dos produtos.",
    )
    parser.add_argument(
        "-o",
        "--output-dir",
        type=Path,
        default=None,
        help="Pasta de saida (padrao: <input_dir>/estudio_1000).",
    )
    parser.add_argument(
        "--template",
        type=Path,
        default=DEFAULT_TEMPLATE,
        help="Caminho do template oficial 1000x1000.",
    )
    parser.add_argument(
        "--height-ratio",
        type=float,
        default=DEFAULT_HEIGHT_RATIO,
        help="Proporcao da altura do produto na zona segura (0.65 a 0.72).",
    )
    parser.add_argument(
        "--max-kb",
        type=int,
        default=DEFAULT_MAX_KB,
        help="Tamanho maximo por arquivo exportado em KB (padrao: 180).",
    )
    parser.add_argument(
        "--bg-threshold",
        type=int,
        default=28,
        help="Tolerancia de cor para o fallback de remocao de fundo.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv if argv is not None else sys.argv[1:])
    output_dir = args.output_dir or (args.input_dir / "estudio_1000")
    count = process_directory(
        input_dir=args.input_dir,
        output_dir=output_dir,
        template_path=args.template,
        height_ratio=args.height_ratio,
        max_kb=args.max_kb,
        bg_threshold=args.bg_threshold,
    )
    print(f"Concluido: {count} produto(s) processado(s) em {output_dir}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
