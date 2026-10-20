// ============================================================================
// 模块名称: ModernSegmentButton.cs
// 所属区域: UI/Controls (基础原子控件层)
// 核心职责:
//   分段按钮项（用于 DPI 档位选择、回报率选择等），具备选中/预设/悬停多种高光模式，
//   支持自定义品牌强调色（AccentColor）、标准无障碍点击动作与选中状态通知。
// 依赖关系: RoundedCard
//
// ⚠️ AI 维护准则 (AI MAINTENANCE DIRECTIVE - DO NOT REMOVE) ⚠️:
// 1. [契约同步更新]: 任何 AI Agent 在修改本文件逻辑、属性或绘图逻辑时，【必须】同步更新上方说明。
// 2. [C# 5 兼容铁律]: 严禁使用 C# 6+ 语法（❌ 严禁 $"..." 插值，必须使用 string.Format 或 + 拼接）。
// 3. [编码格式锁定]: 本文件必须严格保存为【UTF-8 with BOM】编码。
// ============================================================================

using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Windows.Forms;

namespace RazerBatteryTray
{
    public class ModernSegmentButton : Control
    {
        private bool isSelected = false;
        private bool isHovered = false;
        private bool isPreset = false;
        private Color accentColor = Color.FromArgb(0, 200, 83);

        public bool Selected
        {
            get { return isSelected; }
            set { if (isSelected != value) { isSelected = value; Invalidate(); AccessibilityNotifyClients(AccessibleEvents.StateChange, -1); } }
        }

        public bool IsPreset
        {
            get { return isPreset; }
            set { if (isPreset != value) { isPreset = value; Invalidate(); } }
        }

        public Color AccentColor
        {
            get { return accentColor; }
            set { if (accentColor != value) { accentColor = value; Invalidate(); } }
        }

        public ModernSegmentButton()
        {
            Cursor = Cursors.Hand;
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw, true);
        }

        protected override AccessibleObject CreateAccessibilityInstance()
        {
            return new SegmentAccessibleObject(this);
        }
        private sealed class SegmentAccessibleObject : ControlAccessibleObject
        {
            private readonly ModernSegmentButton button;
            public SegmentAccessibleObject(ModernSegmentButton owner) : base(owner) { button = owner; }
            public override AccessibleRole Role { get { return AccessibleRole.PushButton; } }
            public override string Name
            {
                get { return string.IsNullOrEmpty(button.AccessibleName) ? button.Text : button.AccessibleName; }
                set { button.AccessibleName = value; }
            }
            public override string DefaultAction { get { return "Click"; } }
            public override AccessibleStates State
            {
                get { return base.State | (button.Selected ? AccessibleStates.Pressed : AccessibleStates.None); }
            }
            public override void DoDefaultAction()
            {
                if (!button.Enabled || button.IsDisposed) return;
                if (button.InvokeRequired) button.BeginInvoke(new Action(() => { if (button.Enabled && !button.IsDisposed) button.OnClick(EventArgs.Empty); }));
                else button.OnClick(EventArgs.Empty);
            }
        }

        protected override void OnTextChanged(EventArgs e)
        {
            base.OnTextChanged(e);
            Invalidate();
        }

        protected override void OnMouseEnter(EventArgs e) { if (!Enabled) return; base.OnMouseEnter(e); isHovered = true; Invalidate(); }
        protected override void OnMouseLeave(EventArgs e) { if (!Enabled) return; base.OnMouseLeave(e); isHovered = false; Invalidate(); }

        protected override void OnPaint(PaintEventArgs pevent)
        {
            base.OnPaint(pevent);
            Graphics g = pevent.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;

            Color parentBg = (Parent is RoundedCard) ? ((RoundedCard)Parent).CardColor : (Parent != null ? Parent.BackColor : Color.FromArgb(25, 27, 34));
            g.Clear(parentBg);

            Color bg;
            Color border;
            Color fg;

            if (!Enabled)
            {
                if (isSelected)
                {
                    bg = Color.FromArgb(20, 32, 24);
                    border = Color.FromArgb(35, 75, 45);
                    fg = Color.FromArgb(90, 140, 105);
                }
                else
                {
                    bg = Color.FromArgb(22, 24, 30);
                    border = Color.FromArgb(36, 40, 48);
                    fg = Color.FromArgb(80, 85, 95);
                }
            }
            else if (isSelected)
            {
                if (isPreset)
                {
                    bg = isHovered ? Color.FromArgb(24, 48, 32) : Color.FromArgb(18, 34, 24);
                    border = isHovered ? Color.FromArgb(0, 230, 118) : Color.FromArgb(0, 180, 80);
                    fg = isHovered ? Color.White : Color.FromArgb(140, 240, 180);
                }
                else
                {
                    bg = isHovered ? ControlPaint.Light(accentColor, 0.15f) : accentColor;
                    border = accentColor;
                    fg = Color.FromArgb(10, 24, 15);
                }
            }
            else
            {
                bg = isHovered ? Color.FromArgb(38, 42, 54) : Color.FromArgb(28, 30, 38);
                border = isHovered ? Color.FromArgb(80, 88, 108) : Color.FromArgb(48, 52, 65);
                fg = isHovered ? Color.White : Color.FromArgb(180, 188, 205);
            }

            Rectangle rect = new Rectangle(0, 0, Width - 1, Height - 1);
            using (GraphicsPath path = RoundedCard.GetRoundedRectangle(rect, 6))
            {
                using (SolidBrush brush = new SolidBrush(bg))
                {
                    g.FillPath(brush, path);
                }
                using (Pen pen = new Pen(border, 1f))
                {
                    g.DrawPath(pen, path);
                }
            }

            Font useFont = isSelected ? new Font(Font, FontStyle.Bold) : Font;
            TextRenderer.DrawText(g, Text, useFont, ClientRectangle, fg,
                TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.SingleLine);
        }
    }
}
