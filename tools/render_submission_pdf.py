from html import escape
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "submission-application.pdf"
FONT_DIR = Path("C:/Windows/Fonts")


def register_fonts():
    pdfmetrics.registerFont(
        TTFont("MoonChinese", str(FONT_DIR / "msyh.ttc"), subfontIndex=0)
    )
    pdfmetrics.registerFont(
        TTFont("MoonChineseBold", str(FONT_DIR / "msyhbd.ttc"), subfontIndex=0)
    )


def paragraph(text, style):
    return Paragraph(escape(text), style)


def add_footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("MoonChinese", 6.8)
    canvas.setFillColor(colors.HexColor("#607174"))
    canvas.drawString(14 * mm, 8 * mm, "MoonRobots Gate 项目申报书")
    canvas.drawRightString(A4[0] - 14 * mm, 8 * mm, "版本 0.2.0")
    canvas.restoreState()


def main():
    register_fonts()
    styles = getSampleStyleSheet()
    title = ParagraphStyle(
        "TitleCN",
        parent=styles["Title"],
        fontName="MoonChineseBold",
        fontSize=18,
        leading=22,
        textColor=colors.HexColor("#123C43"),
        alignment=1,
        wordWrap="CJK",
        spaceAfter=2,
    )
    subtitle = ParagraphStyle(
        "SubtitleCN",
        parent=styles["BodyText"],
        fontName="MoonChinese",
        fontSize=9.2,
        leading=12.5,
        textColor=colors.HexColor("#405256"),
        alignment=1,
        wordWrap="CJK",
        spaceAfter=5,
    )
    heading = ParagraphStyle(
        "HeadingCN",
        parent=styles["Heading2"],
        fontName="MoonChineseBold",
        fontSize=10.8,
        leading=14,
        textColor=colors.HexColor("#123C43"),
        wordWrap="CJK",
        spaceBefore=5,
        spaceAfter=2,
    )
    body = ParagraphStyle(
        "BodyCN",
        parent=styles["BodyText"],
        fontName="MoonChinese",
        fontSize=8.4,
        leading=12.4,
        textColor=colors.HexColor("#25363A"),
        wordWrap="CJK",
        spaceAfter=2,
    )
    small = ParagraphStyle(
        "SmallCN",
        parent=body,
        fontSize=7.3,
        leading=9.8,
    )

    doc = SimpleDocTemplate(
        str(OUT),
        pagesize=A4,
        rightMargin=14 * mm,
        leftMargin=14 * mm,
        topMargin=10 * mm,
        bottomMargin=12 * mm,
        title="MoonRobots Gate 中文项目申报书",
        author="石子硕",
        subject="8 月 MoonBit 黑客松项目申报材料",
    )

    story = [
        paragraph("MoonRobots Gate", title),
        paragraph(
            "原创 MoonBit 开源库与开发工具｜robots.txt 可解释策略审计与抓取规划",
            subtitle,
        ),
    ]

    metadata = [
        [
            paragraph("参赛者", small),
            paragraph("石子硕", small),
            paragraph("报名邮箱", small),
            paragraph("2111950632@qq.com", small),
        ],
        [
            paragraph("联系电话", small),
            paragraph("18713029718", small),
            paragraph("公开仓库", small),
            paragraph(
                "https://github.com/2111950632/moonrobots-gate",
                small,
            ),
        ],
        [
            paragraph("Mooncakes", small),
            paragraph("2111950632/robots-gate", small),
            paragraph("许可证", small),
            paragraph("Apache-2.0", small),
        ],
    ]
    metadata_table = Table(
        metadata,
        colWidths=[20 * mm, 48 * mm, 23 * mm, 91 * mm],
    )
    metadata_table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (0, -1), colors.HexColor("#DCEBE8")),
                ("BACKGROUND", (2, 0), (2, -1), colors.HexColor("#DCEBE8")),
                ("FONTNAME", (0, 0), (-1, -1), "MoonChinese"),
                ("TEXTCOLOR", (0, 0), (-1, -1), colors.HexColor("#25363A")),
                ("BOX", (0, 0), (-1, -1), 0.4, colors.HexColor("#89A6A0")),
                ("INNERGRID", (0, 0), (-1, -1), 0.2, colors.HexColor("#C2D5D1")),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("LEFTPADDING", (0, 0), (-1, -1), 4),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                ("TOPPADDING", (0, 0), (-1, -1), 2.5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 2.5),
            ]
        )
    )
    story.extend([metadata_table, Spacer(1, 3)])

    metrics = [
        [
            paragraph("核心库 4,284 行", small),
            paragraph("MoonBit 总计 5,745 行", small),
            paragraph("102 项测试通过", small),
            paragraph("12 个核心模块", small),
        ]
    ]
    metrics_table = Table(metrics, colWidths=[45.5 * mm] * 4)
    metrics_table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#F1F6F5")),
                ("FONTNAME", (0, 0), (-1, -1), "MoonChineseBold"),
                ("TEXTCOLOR", (0, 0), (-1, -1), colors.HexColor("#123C43")),
                ("ALIGN", (0, 0), (-1, -1), "CENTER"),
                ("BOX", (0, 0), (-1, -1), 0.35, colors.HexColor("#A8BDB9")),
                ("INNERGRID", (0, 0), (-1, -1), 0.2, colors.HexColor("#D2DFDC")),
                ("TOPPADDING", (0, 0), (-1, -1), 3),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
            ]
        )
    )
    story.append(metrics_table)

    sections = [
        (
            "项目简介",
            "MoonRobots Gate 将 robots.txt 文本转换为可检查的数据模型，为爬虫、搜索索引器、链接检查器、文档工具和 AI 智能体提供确定的访问判断、风险诊断、站点地图校验与抓取规划能力。",
        ),
        (
            "一、项目现有基础",
            "项目已有可运行的 MoonBit 0.2.0 本地原型，完成防御式策略解析、用户代理选择、最长规则匹配、Allow 同长优先、通配符与末尾锚点、百分号编码归一化、决策轨迹、语义检查、策略渲染、访问矩阵、策略差异、站点地图校验和预算抓取规划。现有九组 CLI 命令、四个示例和 102 项测试；格式检查、类型检查、构建、测试和发布包检查均已通过。",
        ),
        (
            "二、本次计划开发或新增的内容",
            "1．增加独立网络获取层，处理重定向、HTTP 状态、正文大小限制、缓存时间和失败回退。2．增加多站点批量审计及 Markdown、JSON、CSV 报告。3．扩充 RFC 9309 兼容性夹具、畸形输入、编码边界和资源上限测试。4．完善 CLI 配置、错误处理、报告导出和真实工作流示例。5．整理公共 API、兼容性、维护和发布文档，并完成公开仓库及 Mooncakes 发布。",
        ),
        (
            "三、预期目标与技术路线",
            "采用“纯策略核心＋可替换传输层”的分层结构：文本先经过限额解析和源位置诊断，再进入用户代理选择与路径匹配；上层复用统一决策结果完成语义审计、版本差异、站点地图检查和抓取规划；传输层只负责网络状态、缓存和内容获取。目标是形成可公开复用、可在 CI 中稳定运行的工具包，预计达到约 7,000 至 9,000 行有效 MoonBit 代码。功能边界不包含页面解析、JavaScript 渲染和完整网络爬虫。",
        ),
        (
            "四、预计完成的功能、测试与文档",
            "功能包括网络获取与缓存、批量审计、结构化报告、完整 CLI、站点地图策略检查和预算抓取规划。测试目标不少于 150 项，覆盖协议语义、异常输入、网络状态、缓存、批量任务和回归夹具。提供策略判断、批量审计、站点地图、抓取规划和 CI 示例。文档包括 README、API 说明、架构设计、协议兼容性、维护指南、更新日志和发布记录。CI 持续验证格式、类型、构建、测试和发布包。",
        ),
        (
            "五、原创性与许可证说明",
            "本项目为原创 MoonBit 实现，不是其他开源库的直接移植，也未复制第三方项目源码。协议行为参考 RFC 9309、RFC 3986 和公开的 Robots 解析文档，仅用于理解公开标准。项目采用 OSI 认可的 Apache-2.0 许可证，核心运行时依赖仅为 moonbitlang/core；新增依赖将在引入前核查许可证并记录来源。",
        ),
    ]

    for section_title, section_body in sections:
        story.append(paragraph(section_title, heading))
        story.append(paragraph(section_body, body))

    story.extend(
        [
            Spacer(1, 2),
            paragraph(
                "报名及材料提交以本次 8 月黑客松飞书问卷和后续官方通知为准。",
                small,
            ),
        ]
    )

    doc.build(story, onFirstPage=add_footer, onLaterPages=add_footer)
    print(OUT)


if __name__ == "__main__":
    main()
