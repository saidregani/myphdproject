from docx.oxml.ns import qn
W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
M = 'http://schemas.openxmlformats.org/officeDocument/2006/math'
ORD = {
 (W, 'style'): 'name aliases basedOn next link autoRedefine hidden uiPriority semiHidden unhideWhenUsed qFormat locked personal personalCompose personalReply rsid pPr rPr tblPr trPr tcPr tblStylePr',
 (W, 'pPr'): 'pStyle keepNext keepLines pageBreakBefore framePr widowControl numPr suppressLineNumbers pBdr shd tabs suppressAutoHyphens kinsoku wordWrap overflowPunct topLinePunct autoSpaceDE autoSpaceDN bidi adjustRightInd snapToGrid spacing ind contextualSpacing mirrorIndents suppressOverlap jc textDirection textAlignment textboxTightWrap outlineLvl divId cnfStyle rPr sectPr pPrChange',
 (W, 'rPr'): 'rStyle rFonts b bCs i iCs caps smallCaps strike dstrike outline shadow emboss imprint noProof snapToGrid vanish webHidden color spacing w kern position sz szCs highlight u effect bdr shd fitText vertAlign rtl cs em lang eastAsianLayout specVanish oMath',
 (W, 'tblPr'): 'tblStyle tblpPr tblOverlap bidiVisual tblStyleRowBandSize tblStyleColBandSize tblW jc tblCellSpacing tblInd tblBorders shd tblLayout tblCellMar tblLook tblCaption tblDescription',
 (W, 'tcPr'): 'cnfStyle tcW gridSpan hMerge vMerge tcBorders shd noWrap tcMar textDirection tcFitText vAlign hideMark',
 (W, 'tcBorders'): 'top start left bottom end right insideH insideV tl2br tr2bl',
 (W, 'tblBorders'): 'top start left bottom end right insideH insideV',
 (W, 'sectPr'): 'headerReference footerReference footnotePr endnotePr type pgSz pgMar paperSrc pgBorders lnNumType pgNumType cols formProt vAlign noEndnote titlePg textDirection bidi rtlGutter docGrid printerSettings sectPrChange',
 (W, 'settings'): 'writeProtection view zoom removePersonalInformation removeDateAndTime doNotDisplayPageBoundaries displayBackgroundShape printPostScriptOverText printFractionalCharacterWidth printFormsData embedTrueTypeFonts embedSystemFonts saveSubsetFonts saveFormsData mirrorMargins alignBordersAndEdges bordersDoNotSurroundHeader bordersDoNotSurroundFooter gutterAtTop hideSpellingErrors hideGrammaticalErrors activeWritingStyle proofState formsDesign attachedTemplate linkStyles stylePaneFormatFilter stylePaneSortMethod documentType mailMerge revisionView trackRevisions doNotTrackMoves doNotTrackFormatting documentProtection autoFormatOverride styleLockTheme styleLockQFSet defaultTabStop autoHyphenation consecutiveHyphenLimit hyphenationZone doNotHyphenateCaps showEnvelope summaryLength clickAndTypeStyle defaultTableStyle evenAndOddHeaders bookFoldRevPrinting bookFoldPrinting bookFoldPrintingSheets drawingGridHorizontalSpacing drawingGridVerticalSpacing displayHorizontalDrawingGridEvery displayVerticalDrawingGridEvery doNotUseMarginsForDrawingGridOrigin drawingGridHorizontalOrigin drawingGridVerticalOrigin doNotShadeFormData noPunctuationKerning characterSpacingControl printTwoOnOne strictFirstAndLastChars noLineBreaksAfter noLineBreaksBefore savePreviewPicture doNotValidateAgainstSchema saveInvalidXml ignoreMixedContent alwaysShowPlaceholderText doNotDemarcateInvalidXml saveXmlDataOnly useXSLTWhenSaving saveThroughXslt showXMLTags alwaysMergeEmptyNamespace updateFields hdrShapeDefaults footnotePr endnotePr compat docVars rsids mathPr attachedSchema themeFontLang clrSchemeMapping doNotIncludeSubdocsInStats doNotAutoCompressPictures forceUpgrade captions readModeInkLockDown smartTagType schemaLibrary shapeDefaults doNotEmbedSmartTags decimalSymbol listSeparator',
 (M, 'rPr'): 'lit nor scr sty brk aln',
 (M, 'dPr'): 'begChr sepChr endChr grow shp ctrlPr',
 (M, 'mcPr'): 'count mcJc',
}
ORD = {('{%s}%s' % k): {n: i for i, n in enumerate(v.split())} for k, v in ORD.items()}
def local(tag): return tag.split('}')[1] if '}' in tag else tag
def normalize(root):
    n = 0
    for el in root.iter():
        o = ORD.get(el.tag)
        if not o: continue
        kids = list(el)
        if not kids: continue
        key = lambda c: o.get(local(c.tag), len(o)) if isinstance(c.tag, str) else len(o)
        srt = sorted(kids, key=key)
        if srt != kids:
            for c in kids: el.remove(c)
            for c in srt: el.append(c)
            n += 1
    for mr in root.iter(qn('m:rPr')):
        if mr.find(qn('m:nor')) is not None:
            for x in mr.findall(qn('m:sty')) + mr.findall(qn('m:scr')): mr.remove(x)
    for el in root.iter(qn('w:rPr')):
        for c in el:
            if c.tail and c.tail.strip(): c.tail = None
    for tp in root.iter(qn('w:tblPr')):
        lays = tp.findall(qn('w:tblLayout'))
        for x in lays[:-1]: tp.remove(x)
    for pm in root.iter(qn('w:pgMar')):
        for a, v in [('w:header', '709'), ('w:gutter', '0'), ('w:footer', '737')]:
            if pm.get(qn(a)) is None: pm.set(qn(a), v)
    for ns_el in root.iter(qn('w:nsid')):
        v = ns_el.get(qn('w:val'))
        if v and len(v) < 8: ns_el.set(qn('w:val'), v.zfill(8))
    return n
