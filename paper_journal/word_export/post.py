"""Format the pandoc output like the LaTeX paper.
usage: python3 post.py raw.docx img_dir out.docx"""
import sys, re, copy
import docx
from docx.shared import Pt, Cm, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH, WD_LINE_SPACING
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml.ns import qn
from docx.oxml import OxmlElement

raw, IMG, out = sys.argv[1:4]
d = docx.Document(raw)
FONT = 'Times New Roman'
TEXTW = 16.0  # cm

# ---------------------------------------------------------------- page setup
for s in d.sections:
    s.page_width, s.page_height = Cm(21.0), Cm(29.7)
    s.left_margin = s.right_margin = s.top_margin = s.bottom_margin = Cm(2.5)
    s.footer_distance = Cm(1.3)
    fp = s.footer.paragraphs[0] if s.footer.paragraphs else s.footer.add_paragraph()
    fp.alignment = WD_ALIGN_PARAGRAPH.CENTER
    fld = OxmlElement('w:fldSimple'); fld.set(qn('w:instr'), 'PAGE')
    r = OxmlElement('w:r'); t = OxmlElement('w:t'); t.text = '1'; r.append(t); fld.append(r)
    fp._p.append(fld)

# ---------------------------------------------------------------- styles
def getsty(name):
    for x in d.styles:
        if x.name == name: return x
    raise KeyError(name)
def set_font(rpr_parent_el, size=None, bold=None, color=None):
    pass
st = d.styles.element
for rf in st.iter(qn('w:rFonts')):
    for a in ['w:asciiTheme', 'w:hAnsiTheme', 'w:eastAsiaTheme', 'w:cstheme']:
        if rf.get(qn(a)) is not None: del rf.attrib[qn(a)]
    for a in ['w:ascii', 'w:hAnsi', 'w:cs']:
        rf.set(qn(a), FONT)
for name in ['Normal', 'Body Text', 'First Paragraph', 'Compact', 'Heading 1', 'Heading 2', 'Heading 3',
             'Title', 'Author', 'Abstract', 'Table Caption', 'Image Caption', 'Caption']:
    try: sty = getsty(name)
    except KeyError: continue
    sty.font.name = FONT
    sty.font.color.rgb = RGBColor(0, 0, 0)
    pf = sty.paragraph_format
    pf.line_spacing_rule = WD_LINE_SPACING.SINGLE
for name in ['Normal', 'Body Text', 'First Paragraph', 'Compact']:
    sty = getsty(name); sty.font.size = Pt(11)
    pf = sty.paragraph_format; pf.space_before = Pt(0); pf.space_after = Pt(3)
    pf.alignment = WD_ALIGN_PARAGRAPH.JUSTIFY
getsty('Body Text').paragraph_format.first_line_indent = Cm(0.5)
getsty('First Paragraph').paragraph_format.first_line_indent = Cm(0)
getsty('Compact').paragraph_format.space_after = Pt(2)
for name, size, before, after in [('Heading 1', 14, 14, 6), ('Heading 2', 12, 10, 4)]:
    sty = getsty(name); sty.font.size = Pt(size); sty.font.bold = True; sty.font.italic = False
    pf = sty.paragraph_format; pf.space_before = Pt(before); pf.space_after = Pt(after)
    pf.keep_with_next = True; pf.alignment = WD_ALIGN_PARAGRAPH.LEFT
# default run font (docDefaults)
for rf in st.iter(qn('w:rFonts')):
    pass

body = d.element.body
def text_of(p): return ''.join(t.text or '' for t in p._p.iter(qn('w:t')))
def strip_marker(p, marker):
    for t in p._p.iter(qn('w:t')):
        if t.text and marker in t.text:
            t.text = t.text.replace(marker, '', 1).lstrip(); return
def runs_size(p, size, bold=None):
    for r in p.runs:
        r.font.size = Pt(size); r.font.name = FONT
        if bold is not None: r.font.bold = bold
    for mr in p._p.iter(qn('m:r')):
        pass
def pf(p, align=None, before=None, after=None, indent=0, keep=None, hanging=None):
    f = p.paragraph_format
    if align is not None: p.alignment = align
    if before is not None: f.space_before = Pt(before)
    if after is not None: f.space_after = Pt(after)
    f.first_line_indent = Cm(indent)
    if hanging is not None: f.left_indent = Cm(hanging); f.first_line_indent = Cm(-hanging)
    if keep is not None: f.keep_with_next = keep

def no_borders(tbl):
    tblPr = tbl._tbl.tblPr
    b = OxmlElement('w:tblBorders')
    for e in ['top', 'left', 'bottom', 'right', 'insideH', 'insideV']:
        x = OxmlElement(f'w:{e}'); x.set(qn('w:val'), 'nil'); b.append(x)
    old = tblPr.find(qn('w:tblBorders'))
    if old is not None: tblPr.remove(old)
    tblPr.append(b)

def cell_border(cell, **kw):
    tcPr = cell._tc.get_or_add_tcPr()
    b = tcPr.find(qn('w:tcBorders'))
    if b is None: b = OxmlElement('w:tcBorders'); tcPr.append(b)
    for edge, sz in kw.items():
        x = b.find(qn(f'w:{edge}'))
        if x is None: x = OxmlElement(f'w:{edge}'); b.append(x)
        x.set(qn('w:val'), 'single'); x.set(qn('w:sz'), str(sz)); x.set(qn('w:space'), '0'); x.set(qn('w:color'), '000000')

def set_widths(tbl, widths_cm):
    tbl.autofit = False
    tblPr = tbl._tbl.tblPr
    lay = OxmlElement('w:tblLayout'); lay.set(qn('w:type'), 'fixed'); tblPr.append(lay)
    tw = tblPr.find(qn('w:tblW'))
    if tw is None: tw = OxmlElement('w:tblW'); tblPr.append(tw)
    tw.set(qn('w:w'), str(int(sum(widths_cm) * 567))); tw.set(qn('w:type'), 'dxa')
    grid = tbl._tbl.tblGrid
    for gc, w in zip(grid.findall(qn('w:gridCol')), widths_cm): gc.set(qn('w:w'), str(int(w * 567)))
    for row in tbl.rows:
        for c, w in zip(row.cells, widths_cm): c.width = Cm(w)

# ---------------------------------------------------------------- equations
paras = list(d.paragraphs)
for i, p in enumerate(paras):
    m = re.fullmatch(r'\s*@@EQ:(\d+)@@\s*', text_of(p))
    if not m: continue
    peq = paras[i - 1]
    omp = peq._p.find('.//' + qn('m:oMathPara'))
    assert omp is not None, ('no math before', m.group(1))
    tbl = d.add_table(rows=1, cols=3)
    no_borders(tbl); set_widths(tbl, [1.4, 13.2, 1.4]); tbl.alignment = WD_TABLE_ALIGNMENT.CENTER
    c0, c1, c2 = tbl.rows[0].cells
    for c in (c0, c1, c2): c.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
    q = c1.paragraphs[0]; q._p.append(omp); pf(q, WD_ALIGN_PARAGRAPH.CENTER, 3, 3)
    q2 = c2.paragraphs[0]; r = q2.add_run(f'({m.group(1)})'); r.font.size = Pt(11); r.font.name = FONT
    pf(q2, WD_ALIGN_PARAGRAPH.RIGHT, 3, 3); pf(c0.paragraphs[0], None, 3, 3)
    peq._p.addprevious(tbl._tbl)
    peq._p.getparent().remove(peq._p); p._p.getparent().remove(p._p)
    # text right after an equation continues the paragraph: no indent
    nxt = tbl._tbl.getnext()
    if nxt is not None and nxt.tag == qn('w:p'):
        ppr = nxt.get_or_add_pPr()
        ind = ppr.find(qn('w:ind'))
        if ind is None: ind = OxmlElement('w:ind'); ppr.append(ind)
        ind.set(qn('w:firstLine'), '0')

# ---------------------------------------------------------------- markers
for p in list(d.paragraphs):
    tx = text_of(p)
    if tx.startswith('@@TITLE@@'):
        strip_marker(p, '@@TITLE@@'); runs_size(p, 17, True); pf(p, WD_ALIGN_PARAGRAPH.CENTER, 0, 14)
    elif tx.startswith('@@AUTHORS@@'):
        strip_marker(p, '@@AUTHORS@@'); runs_size(p, 12.5); pf(p, WD_ALIGN_PARAGRAPH.CENTER, 0, 8)
    elif tx.startswith('@@AFF@@'):
        strip_marker(p, '@@AFF@@'); runs_size(p, 9.5); pf(p, WD_ALIGN_PARAGRAPH.CENTER, 0, 0)
    elif tx.startswith('@@IMG:'):
        f, frac = re.match(r'@@IMG:([^:]+):([^@]+)@@', tx).groups()
        for r in list(p.runs): r._r.getparent().remove(r._r)
        p.add_run().add_picture(f'{IMG}/{f}', width=Cm(TEXTW * float(frac)))
        pf(p, WD_ALIGN_PARAGRAPH.CENTER, 8, 4, keep=True)
    elif tx.startswith('@@CAP@@'):
        strip_marker(p, '@@CAP@@'); runs_size(p, 10)
        pf(p, WD_ALIGN_PARAGRAPH.CENTER if len(text_of(p)) < 105 else WD_ALIGN_PARAGRAPH.JUSTIFY, 2, 10)
    elif tx.startswith('@@TCAP@@'):
        strip_marker(p, '@@TCAP@@'); runs_size(p, 10)
        pf(p, WD_ALIGN_PARAGRAPH.CENTER if len(text_of(p)) < 105 else WD_ALIGN_PARAGRAPH.JUSTIFY, 10, 4, keep=True)
    elif tx.startswith('@@TFOOT@@'):
        strip_marker(p, '@@TFOOT@@'); runs_size(p, 9); pf(p, WD_ALIGN_PARAGRAPH.CENTER, 2, 8)
    elif tx.startswith('@@BIB@@'):
        strip_marker(p, '@@BIB@@'); runs_size(p, 10); pf(p, WD_ALIGN_PARAGRAPH.JUSTIFY, 0, 2, hanging=0.8)
    elif tx.startswith(('Abstract:', 'Keywords:')):
        pf(p, WD_ALIGN_PARAGRAPH.JUSTIFY, 4, 4)
    elif tx.startswith(('Author Contributions:', 'Funding:', 'Data Availability Statement:', 'Conflicts of Interest:')):
        runs_size(p, 10); pf(p, WD_ALIGN_PARAGRAPH.JUSTIFY, 0 if not tx.startswith('Author') else 12, 2)
    elif tx.startswith(('Theorem', 'Remark', 'Proof.')):
        pf(p, WD_ALIGN_PARAGRAPH.JUSTIFY, 4, 3)

# ---------------------------------------------------------------- data tables (booktabs look)
data_tables = [t for t in d.tables if len(t.columns) != 3 or t.rows[0].cells[0].paragraphs[0].text != '']
data_tables = [t for t in d.tables if not (len(t.rows) == 1 and len(t.columns) == 3)]
THICK, THIN = 12, 6
for k, t in enumerate(data_tables):
    t.alignment = WD_TABLE_ALIGNMENT.CENTER
    tblPr = t._tbl.tblPr
    sty = tblPr.find(qn('w:tblStyle'))
    no_borders(t)
    for row in t.rows:
        for c in row.cells:
            c.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
            for q in c.paragraphs:
                pf(q, None, 1, 1)
                for r in q.runs: r.font.size = Pt(10); r.font.name = FONT
    nh = 2 if k == 3 else 1
    for c in t.rows[0].cells: cell_border(c, top=THICK)
    for c in t.rows[nh - 1].cells: cell_border(c, bottom=THIN)
    for c in t.rows[-1].cells: cell_border(c, bottom=THICK)
    if k == 3:   # cmidrules under the case names
        for c in t.rows[0].cells[1:]: cell_border(c, bottom=THIN)
    if k == 2:   # midrules between the cases
        for row in t.rows[2:]:
            if row.cells[0].text.strip():
                for c in row.cells: cell_border(c, top=THIN)
    # alignment: first column left, others centered (as in the LaTeX tables)
    for row in t.rows:
        for j, c in enumerate(row.cells):
            for q in c.paragraphs:
                q.alignment = WD_ALIGN_PARAGRAPH.LEFT if (j == 0 or (k == 2 and j == 1) or (k in (0, 1))) else WD_ALIGN_PARAGRAPH.CENTER
    for row in t.rows:   # header rows repeat, rows do not split
        trPr = row._tr.get_or_add_trPr()
        cs = OxmlElement('w:cantSplit'); trPr.append(cs)
widths = {0: [5.6, 2.2, 4.4, 2.6], 1: [3.6, 12.0], 2: [3.0, 4.0, 2.6, 2.4, 3.2], 3: [4.6] + [1.7] * 6}
for k, t in enumerate(data_tables):
    set_widths(t, widths[k])

import importlib.util as _u
_spec = _u.spec_from_file_location('norm', __file__.replace('post.py', 'norm.py')); _n = _u.module_from_spec(_spec); _spec.loader.exec_module(_n)
parts = [d.element, d.styles.element, d.settings.element]
try: parts.append(d.part.numbering_part.element)
except Exception: pass
print('normalized', sum(_n.normalize(x) for x in parts))
d.save(out)
print('ok', len(d.tables), 'tables')
