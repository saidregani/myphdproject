"""LaTeX (paper_journal/main.tex) -> pandoc-friendly LaTeX with all numbers resolved.
usage: python3 pre.py main.tex main.aux out.tex"""
import re, sys
src, aux, out = sys.argv[1:4]
s = open(src, encoding='utf-8').read()
s = s[s.index('\\begin{document}') + len('\\begin{document}'):s.index('\\end{document}')]
s = re.sub(r'(?m)^%.*\n', '', s)

# ---- macros
s = re.sub(r'\\bv\{([^}]*)\}', r'\\mathbf{\1}', s)
s = s.replace('\\Jm', '\\boldsymbol{\\mathcal{J}}')
s = s.replace('\\tfrac', '\\frac')
s = re.sub(r'\$\^\{?([^}$]+)\}?\$', r'\\textsuperscript{\1}', s)
for x, y in [('\\Bigl', '\\left'), ('\\Bigr', '\\right'), ('\\bigl', '\\left'), ('\\bigr', '\\right')]:
    s = s.replace(x, y)

# ---- labels from the LaTeX run (checked against our own counters below)
lab = dict(re.findall(r'\\newlabel\{([^}]*)\}\{\{([^}]*)\}', open(aux).read()))

# ---- citations: numbers in bibliography order
keys = re.findall(r'\\bibitem\{([^}]*)\}', s)
num = {k: i + 1 for i, k in enumerate(keys)}
s = re.sub(r'\\cite\{([^}]*)\}', lambda m: '[' + ', '.join(str(num[k.strip()]) for k in m.group(1).split(',')) + ']', s)
s = re.sub(r'\\ref\{([^}]*)\}', lambda m: lab[m.group(1)], s)

# ---- title block
t = re.search(r'\\begin\{center\}(.*?)\\end\{center\}', s, re.S)
title = re.search(r'\\bfseries (.*?)\\par', t.group(1), re.S).group(1)
authors = re.search(r'\\large (.*?)\\par', t.group(1), re.S).group(1).replace('\\,', '')
aff = re.search(r'\\small (.*?)\\par', t.group(1), re.S).group(1)
aff_lines = [a.strip() for a in aff.split('\\\\')]
blk = '@@TITLE@@ ' + ' '.join(title.split()) + '\n\n@@AUTHORS@@ ' + authors + '\n\n'
blk += ''.join('@@AFF@@ ' + a + '\n\n' for a in aff_lines)
s = s[:t.start()] + blk + s[t.end():]

# ---- sections with explicit numbers
cs = [0, 0]
def sec(m):
    if m.group(1) == 'section':
        cs[0] += 1; cs[1] = 0; return f'\\section*{{{cs[0]}. {m.group(2)}}}'
    cs[1] += 1; return f'\\subsection*{{{cs[0]}.{cs[1]}. {m.group(2)}}}'
s = re.sub(r'\\(section|subsection)\{((?:[^{}]|\{[^{}]*\})*)\}', sec, s)

# ---- equations: one standalone display per number, marker paragraph after it
neq = [0]
def eqn(body):
    neq[0] += 1
    body = re.sub(r'\\label\{([^}]*)\}', lambda m: chk(m.group(1), neq[0]), body)
    return f'\n\n$${body.strip()}$$\n\n@@EQ:{neq[0]}@@\n\n'
def chk(l, n):
    assert lab[l] == str(n), (l, lab[l], n)
    return ''
s = re.sub(r'\\begin\{(equation|align)\}(.*?)\\end\{\1\}',
           lambda m: eqn(m.group(2)) if m.group(1) == 'equation'
           else ''.join(eqn(x.replace('&', '')) for x in m.group(2).split('\\\\')), s, flags=re.S)

# ---- theorems, remarks, proofs

def emph_paras(body, label):
    def enum(m):
        items = re.split(r'\\item', m.group(1))[1:]
        return ''.join(f'\n\n({r}) ' + it.strip() + '\n\n' for r, it in zip(['i', 'ii', 'iii', 'iv', 'v'], items))
    body = re.sub(r'\\begin\{enumerate\}(?:\[[^\]]*\])?(.*?)\\end\{enumerate\}', enum, body, flags=re.S)
    out = []
    for k, p in enumerate(x for x in re.split(r'\n\s*\n', body) if x.strip()):
        p = p.strip()
        if p.startswith(('$$', '@@')): out.append(p); continue
        out.append(('\\textbf{' + label + '} ' if k == 0 else '') + '\\emph{' + p + '}')
    return '\n\n' + '\n\n'.join(out) + '\n\n'
nth = [0]; nre = [0]
def theorem(m):
    nth[0] += 1; return emph_paras(m.group(1), f'Theorem {nth[0]}.')
def remark(m):
    nre[0] += 1; return emph_paras(m.group(1), f'Remark {nre[0]}.')
s = re.sub(r'\\begin\{theorem\}(.*?)\\end\{theorem\}', theorem, s, flags=re.S)
s = re.sub(r'\\begin\{remark\}(.*?)\\end\{remark\}', remark, s, flags=re.S)
npr = [0]; nas = [0]
def prop(m):
    npr[0] += 1; return emph_paras(m.group(1), f'Proposition {npr[0]}.')
def assum(m):
    nas[0] += 1; return emph_paras(m.group(1), f'Assumption {nas[0]}.')
s = re.sub(r'\\begin\{proposition\}(.*?)\\end\{proposition\}', prop, s, flags=re.S)
s = re.sub(r'\\begin\{assumption\}(.*?)\\end\{assumption\}', assum, s, flags=re.S)
s = s.replace('\\begin{enumerate}[label=(\\roman*),leftmargin=*,itemsep=1pt]', '\\begin{enumerate}')
s = re.sub(r'\\begin\{proof\}(.*?)\\end\{proof\}', lambda m: '\n\n\\emph{Proof.} ' + m.group(1).strip() + ' @@QED@@\n\n', s, flags=re.S)

# ---- figures: image paragraph + caption paragraph
nfig = [0]
def figure(m):
    nfig[0] += 1; b = m.group(1)
    w, f = re.search(r'\\includegraphics\[width=([^\]]*)\]\{([^}]*)\}', b).groups()
    frac = w.replace('\\textwidth', '').strip() or '1'
    cap = re.search(r'\\caption\{(.*)\}\s*\\label', b, re.S).group(1)
    l = re.search(r'\\label\{([^}]*)\}', b).group(1); chk(l, nfig[0])
    return (f'\n\n@@IMG:{f.replace(".pdf", ".png")}:{frac}@@\n\n'
            f'@@CAP@@ \\textbf{{Figure {nfig[0]}.}} {" ".join(cap.split())}\n\n')
s = re.sub(r'\\begin\{figure\}\[[^\]]*\](.*?)\\end\{figure\}', figure, s, flags=re.S)

# ---- tables: caption paragraph above the tabular, footnote kept as a paragraph
ntab = [0]
def table(m):
    ntab[0] += 1; b = m.group(1)
    cap = re.search(r'\\caption\{(.*?)\}\s*\\label', b, re.S).group(1)
    l = re.search(r'\\label\{([^}]*)\}', b).group(1); chk(l, ntab[0])
    tab = re.search(r'\\begin\{tabular\}.*?\\end\{tabular\}', b, re.S).group(0)
    foot = re.search(r'\\end\{tabular\}\s*\\vspace\{[^}]*\}\{\\footnotesize (.*?)\}\s*$', b, re.S)
    o = f'\n\n@@TCAP@@ \\textbf{{Table {ntab[0]}.}} {" ".join(cap.split())}\n\n{tab}\n\n'
    if foot: o += f'@@TFOOT@@ {foot.group(1)}\n\n'
    return o
s = re.sub(r'\\begin\{table\}\[[^\]]*\](.*?)\\end\{table\}', table, s, flags=re.S)

# ---- bibliography
def bib(m):
    items = re.split(r'\\bibitem\{([^}]*)\}', m.group(1))[1:]
    o = '\n\n\\section*{References}\n\n'
    for k, txt in zip(items[0::2], items[1::2]):
        o += f'@@BIB@@ [{num[k]}] {" ".join(txt.split())}\n\n'
    return o
s = re.sub(r'\\begin\{thebibliography\}\{[^}]*\}(.*?)\\end\{thebibliography\}', bib, s, flags=re.S)

# ---- layout commands without meaning in Word
for c in [r'\\vspace\{[^}]*\}', r'\\noindent', r'\\normalsize', r'\\small', r'\\footnotesize', r'\\centering',
          r'\\setlength\{[^}]*\}\{[^}]*\}']:
    s = re.sub(c, '', s)
s = s.replace('[leftmargin=*,itemsep=2pt]', '')
s = re.sub(r'\\cmidrule\(lr\)\{[^}]*\}', '', s)
s = s.replace('@@QED@@', '$\\square$')
s = re.sub(r'\n{3,}', '\n\n', s)
print('equations', neq[0], 'figures', nfig[0], 'tables', ntab[0], 'refs', len(keys))
open(out, 'w', encoding='utf-8').write('\\documentclass{article}\n\\usepackage{amsmath}\n\\begin{document}\n' + s + '\n\\end{document}\n')
