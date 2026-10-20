"""Build the one-page quick-start PDF from docs/INSTRUCTIONS.md (ReportLab)."""
from pathlib import Path
import re
from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle
from xml.sax.saxutils import escape

root = Path(__file__).resolve().parents[1]
source = (root / 'docs/INSTRUCTIONS.md').read_text(encoding='utf-8')
output = root / 'docs/INSTRUCTIONS.pdf'
body = ParagraphStyle('Body', fontName='Helvetica', fontSize=9, leading=11.5, spaceAfter=7)
title = ParagraphStyle('Title', parent=body, fontName='Helvetica-Bold', fontSize=18, leading=22, spaceAfter=9)
small = ParagraphStyle('Small', parent=body, fontSize=8.4, leading=10.6, spaceAfter=5)

def markup(text):
    text = escape(text)
    text = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', text)
    return re.sub(r'`([^`]+)`', r'<font name="Courier">\1</font>', text)

story = []
for block in source.strip().split('\n\n'):
    if block.startswith('# '):
        story.append(Paragraph(markup(block[2:]), title))
    elif block.startswith('|'):
        rows = [[Paragraph(markup(c.strip()), small) for c in line.strip('|').split('|')]
                for line in block.splitlines() if not re.match(r'^\|[\s:|-]+\|$', line)]
        table = Table(rows, colWidths=[180, 360], hAlign='LEFT')
        table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#e8eef4')),
            ('GRID', (0, 0), (-1, -1), 0.35, colors.HexColor('#b8c4cf')),
            ('VALIGN', (0, 0), (-1, -1), 'TOP'),
            ('TOPPADDING', (0, 0), (-1, -1), 3),
            ('BOTTOMPADDING', (0, 0), (-1, -1), 2),
        ]))
        story.extend([table, Spacer(1, 8)])
    elif re.match(r'^\d+\. ', block):
        for step in block.splitlines():
            story.append(Paragraph(markup(step), body))
    else:
        style = small if block.startswith('**') else body
        story.append(Paragraph(markup(block.replace('\n', ' ')), style))

def footer(canvas, doc):
    canvas.setFont('Helvetica', 8)
    canvas.setFillColor(colors.HexColor('#526273'))
    canvas.drawString(36, 20, 'V1.2 | Quick-start instructions | Full details: README.md')
    canvas.drawRightString(576, 20, str(doc.page))

doc = SimpleDocTemplate(str(output), pagesize=letter, rightMargin=36, leftMargin=36,
                       topMargin=30, bottomMargin=33, title='Fiber Photometry Behavior Analyzer V1.2 - Instructions',
                       author='superdongping')
doc.build(story, onFirstPage=footer, onLaterPages=footer)
print(output)
