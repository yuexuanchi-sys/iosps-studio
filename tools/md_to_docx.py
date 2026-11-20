# -*- coding: utf-8 -*-
"""Convert the research report Markdown into a formatted Word document."""
import re
import sys
from pathlib import Path

from docx import Document
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor
from docx.opc.constants import RELATIONSHIP_TYPE

_ROOT = Path(__file__).resolve().parent.parent
SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else _ROOT / "docs" / "research" / "调研报告.md"
OUT = Path(sys.argv[2]) if len(sys.argv) > 2 else SRC.with_suffix(".docx")

EA_FONT = "微软雅黑"
EA_SERIF = "微软雅黑"
LATIN_FONT = "Segoe UI"
ACCENT = RGBColor(0x1F, 0x38, 0x64)
ACCENT2 = RGBColor(0x2E, 0x74, 0xB5)
GRAY = RGBColor(0x59, 0x59, 0x59)


def set_run_font(run, size=None, bold=None, italic=None, color=None, latin=LATIN_FONT, ea=EA_FONT):
    if size is not None:
        run.font.size = Pt(size)
    if bold is not None:
        run.font.bold = bold
    if italic is not None:
        run.font.italic = italic
    if color is not None:
        run.font.color.rgb = color
    run.font.name = latin
    rPr = run._element.get_or_add_rPr()
    rFonts = rPr.find(qn("w:rFonts"))
    if rFonts is None:
        rFonts = OxmlElement("w:rFonts")
        rPr.append(rFonts)
    rFonts.set(qn("w:ascii"), latin)
    rFonts.set(qn("w:hAnsi"), latin)
    rFonts.set(qn("w:eastAsia"), ea)


def add_page_field(paragraph):
    run = paragraph.add_run("第 ")
    set_run_font(run, 9, color=GRAY)
    run = paragraph.add_run()
    fld1 = OxmlElement("w:fldChar"); fld1.set(qn("w:fldCharType"), "begin")
    instr = OxmlElement("w:instrText"); instr.set(qn("xml:space"), "preserve"); instr.text = "PAGE"
    fld2 = OxmlElement("w:fldChar"); fld2.set(qn("w:fldCharType"), "end")
    run._r.append(fld1); run._r.append(instr); run._r.append(fld2)
    set_run_font(run, 9, color=GRAY)
    run = paragraph.add_run(" 页")
    set_run_font(run, 9, color=GRAY)


def add_hyperlink(paragraph, url, text, size=None):
    part = paragraph.part
    r_id = part.relate_to(url, RELATIONSHIP_TYPE.HYPERLINK, is_external=True)
    hyperlink = OxmlElement("w:hyperlink")
    hyperlink.set(qn("r:id"), r_id)
    new_run = OxmlElement("w:r")
    rPr = OxmlElement("w:rPr")
    color = OxmlElement("w:color"); color.set(qn("w:val"), "0563C1"); rPr.append(color)
    u = OxmlElement("w:u"); u.set(qn("w:val"), "single"); rPr.append(u)
    if size:
        sz = OxmlElement("w:sz"); sz.set(qn("w:val"), str(int(size * 2))); rPr.append(sz)
    new_run.append(rPr)
    t = OxmlElement("w:t"); t.text = text; t.set(qn("xml:space"), "preserve")
    new_run.append(t)
    hyperlink.append(new_run)
    paragraph._p.append(hyperlink)


INLINE_RE = re.compile(r"(\*\*.+?\*\*|`[^`]+`|\[[^\]]+\]\([^)]+\)|\*[^*\n]+\*|<https?://[^>\s]+>)")


def add_inline(paragraph, text, size=10.5, base_bold=False, color=None):
    for token in INLINE_RE.split(text):
        if not token:
            continue
        m = re.fullmatch(r"\*\*(.+?)\*\*", token, re.S)
        if m:
            run = paragraph.add_run(m.group(1))
            set_run_font(run, size, bold=True, color=color)
            continue
        m = re.fullmatch(r"`([^`]+)`", token, re.S)
        if m:
            run = paragraph.add_run(m.group(1))
            set_run_font(run, size - 0.5, color=RGBColor(0x8B, 0x1A, 0x1A), latin="Consolas", ea=EA_FONT)
            continue
        m = re.fullmatch(r"\[([^\]]+)\]\(([^)]+)\)", token, re.S)
        if m:
            add_hyperlink(paragraph, m.group(2), m.group(1), size=size)
            continue
        m = re.fullmatch(r"\*([^*\n]+)\*", token, re.S)
        if m:
            run = paragraph.add_run(m.group(1))
            set_run_font(run, size, italic=True, color=color)
            continue
        m = re.fullmatch(r"<(https?://[^>\s]+)>", token, re.S)
        if m:
            add_hyperlink(paragraph, m.group(1), m.group(1), size=size)
            continue
        run = paragraph.add_run(token)
        set_run_font(run, size, bold=base_bold, color=color)


def style_document(doc):
    normal = doc.styles["Normal"]
    normal.font.name = LATIN_FONT
    normal.font.size = Pt(10.5)
    normal.element.rPr.rFonts.set(qn("w:eastAsia"), EA_FONT)
    pf = normal.paragraph_format
    pf.line_spacing = 1.25
    pf.space_after = Pt(4)

    for name, size, color in (("Heading 1", 15, ACCENT), ("Heading 2", 13, ACCENT2), ("Heading 3", 11.5, ACCENT)):
        st = doc.styles[name]
        st.font.name = LATIN_FONT
        st.font.size = Pt(size)
        st.font.bold = True
        st.font.color.rgb = color
        st.element.rPr.rFonts.set(qn("w:eastAsia"), EA_FONT)
        st.paragraph_format.space_before = Pt(12)
        st.paragraph_format.space_after = Pt(6)
        st.paragraph_format.keep_with_next = True

    title = doc.styles["Title"]
    title.font.name = LATIN_FONT
    title.font.size = Pt(24)
    title.font.bold = True
    title.font.color.rgb = ACCENT
    title.element.rPr.rFonts.set(qn("w:eastAsia"), EA_FONT)
    title.paragraph_format.space_after = Pt(6)


def setup_page(doc):
    section = doc.sections[0]
    section.page_width = Cm(21.0)
    section.page_height = Cm(29.7)
    section.top_margin = Cm(2.0)
    section.bottom_margin = Cm(2.0)
    section.left_margin = Cm(2.2)
    section.right_margin = Cm(2.2)
    footer = section.footer.paragraphs[0]
    footer.alignment = WD_ALIGN_PARAGRAPH.CENTER
    run = footer.add_run("iOS 生日礼物 App（P图 + 视频剪辑）前期调研报告 · 2026-11-20 ｜ ")
    set_run_font(run, 9, color=GRAY)
    add_page_field(footer)


def shade_cell(cell, hex_fill):
    tcPr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), hex_fill)
    tcPr.append(shd)


def mark_header_row(row):
    trPr = row._tr.get_or_add_trPr()
    tblHeader = OxmlElement("w:tblHeader")
    tblHeader.set(qn("w:val"), "true")
    trPr.append(tblHeader)


def split_row(line):
    line = line.strip()
    if line.startswith("|"):
        line = line[1:]
    if line.endswith("|"):
        line = line[:-1]
    return [c.strip() for c in line.split("|")]


def add_table(doc, rows):
    header = split_row(rows[0])
    body = [split_row(r) for r in rows[1:] if not re.fullmatch(r"[\s|:\-]+", r.strip())]
    ncol = len(header)
    body = [(r + [""] * ncol)[:ncol] for r in body]
    table = doc.add_table(rows=1, cols=ncol)
    try:
        table.style = "Light Grid Accent 1"
    except Exception:
        table.style = "Table Grid"
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = True

    hdr = table.rows[0]
    mark_header_row(hdr)
    for i, text in enumerate(header):
        cell = hdr.cells[i]
        cell.text = ""
        p = cell.paragraphs[0]
        add_inline(p, text, size=9, base_bold=True, color=RGBColor(0xFF, 0xFF, 0xFF))
        shade_cell(cell, "1F3864")

    for row_vals in body:
        cells = table.add_row().cells
        for i, text in enumerate(row_vals):
            cells[i].text = ""
            p = cells[i].paragraphs[0]
            add_inline(p, text, size=9)

    for row in table.rows:
        for cell in row.cells:
            for p in cell.paragraphs:
                p.paragraph_format.space_after = Pt(1)
                p.paragraph_format.line_spacing = 1.1
    doc.add_paragraph()


def build():
    md = SRC.read_text(encoding="utf-8")
    lines = md.splitlines()
    doc = Document()
    style_document(doc)
    setup_page(doc)

    doc.core_properties.title = "iOS 生日礼物 App（P图 + 视频剪辑）前期调研报告"
    doc.core_properties.subject = "iOS 图像/视频编辑开源生态、产品方案与落地方案调研"
    doc.core_properties.author = "DeepSeek Harness 调研"
    doc.core_properties.keywords = "iOS, P图, 视频剪辑, 开源, 生日App, 调研"

    i = 0
    first_h1 = True
    while i < len(lines):
        raw = lines[i]
        line = raw.strip()

        if not line or re.fullmatch(r"[-*_]{3,}", line):
            i += 1
            continue

        # headings
        m = re.match(r"^(#{1,4})\s+(.*)$", line)
        if m:
            level = len(m.group(1))
            text = m.group(2).strip()
            if level == 1 and first_h1:
                p = doc.add_paragraph(style="Title")
                add_inline(p, text, size=24, base_bold=True, color=ACCENT)
                first_h1 = False
            else:
                p = doc.add_paragraph(style=f"Heading {min(level - 1, 3)}")
                add_inline(p, text, size=15 if level <= 2 else 12, base_bold=True,
                           color=ACCENT if level <= 2 else ACCENT2)
            i += 1
            continue

        # blockquote
        if line.startswith(">"):
            quote_lines = []
            while i < len(lines) and lines[i].strip().startswith(">"):
                quote_lines.append(lines[i].strip().lstrip(">").strip())
                i += 1
            p = doc.add_paragraph()
            p.paragraph_format.left_indent = Cm(0.5)
            add_inline(p, "▎ " + " ".join(quote_lines), size=9.5, color=GRAY)
            continue

        # table
        if line.startswith("|"):
            table_rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                table_rows.append(lines[i].strip())
                i += 1
            if len(table_rows) >= 2:
                add_table(doc, table_rows)
            continue

        # bullet list
        m = re.match(r"^[-*]\s+(.*)$", line)
        if m:
            p = doc.add_paragraph(style="List Bullet")
            add_inline(p, m.group(1))
            i += 1
            continue

        # numbered list
        m = re.match(r"^(\d+)\.\s+(.*)$", line)
        if m:
            p = doc.add_paragraph(style="List Number")
            add_inline(p, m.group(2))
            i += 1
            continue

        # ordinary paragraph: collect continuation lines
        para_lines = [line]
        i += 1
        while i < len(lines):
            nxt = lines[i].strip()
            if (not nxt or nxt.startswith(("#", ">", "|", "- ", "* ")) or re.match(r"^\d+\.\s", nxt)
                    or re.fullmatch(r"[-*_]{3,}", nxt)):
                break
            para_lines.append(nxt)
            i += 1
        text = " ".join(para_lines)
        p = doc.add_paragraph()
        p.paragraph_format.first_line_indent = Cm(0)
        add_inline(p, text)

    doc.save(str(OUT))
    return OUT


if __name__ == "__main__":
    out = build()
    print(f"SAVED: {out}")
    from docx import Document as D2
    d = D2(str(out))
    print(f"paragraphs={len(d.paragraphs)} tables={len(d.tables)}")
    print("first:", d.paragraphs[0].text[:60])
    print("last:", d.paragraphs[-1].text[:60])
