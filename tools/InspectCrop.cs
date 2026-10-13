using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Windows.Forms;
using RazerBatteryTray;

class InspectCrop
{
    [STAThread]
    static void Main()
    {
        MainForm form = new MainForm();
        form.StartPosition = FormStartPosition.Manual;
        form.Location = new Point(100, 100);
        form.Show();
        Application.DoEvents();

        Bitmap fullBmp = new Bitmap(form.Width, form.Height);
        form.DrawToBitmap(fullBmp, new Rectangle(0, 0, form.Width, form.Height));

        Console.WriteLine(string.Format("Form: {0}x{1}, Client: {2}x{3}", form.Width, form.Height, form.ClientSize.Width, form.ClientSize.Height));

        // Find client area offset by searching for dark background (R < 30, G < 30, B < 30)
        int clientTop = 0;
        int clientLeft = 0;
        for (int y = 0; y < fullBmp.Height / 3; y++)
        {
            Color c = fullBmp.GetPixel(fullBmp.Width / 2, y);
            if (c.R >= 16 && c.R <= 22 && c.G >= 16 && c.G <= 24 && c.B >= 20 && c.B <= 28)
            {
                clientTop = y;
                break;
            }
        }
        for (int x = 0; x < fullBmp.Width / 4; x++)
        {
            Color c = fullBmp.GetPixel(x, clientTop + 20);
            if (c.R >= 16 && c.R <= 22 && c.G >= 16 && c.G <= 24 && c.B >= 20 && c.B <= 28)
            {
                clientLeft = x;
                break;
            }
        }

        Console.WriteLine(string.Format("Detected Client Offset: Left={0}, Top={1}", clientLeft, clientTop));

        // Crop pure client area
        Rectangle clientRect = new Rectangle(clientLeft, clientTop, form.ClientSize.Width, form.ClientSize.Height);
        Bitmap clientOnly = fullBmp.Clone(clientRect, fullBmp.PixelFormat);
        clientOnly.Save(@"promo\dist\test_client_only.png", ImageFormat.Png);
        Console.WriteLine("Saved test_client_only.png");

        // Now compose with authentic Win11 Dark Title Bar
        int titleH = 34;
        Bitmap modernDarkWindow = new Bitmap(form.ClientSize.Width, form.ClientSize.Height + titleH);
        using (Graphics g = Graphics.FromImage(modernDarkWindow))
        {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;

            // Fill Win11 Immersive Dark Caption (#0c0c0e)
            using (SolidBrush bgBrush = new SolidBrush(Color.FromArgb(12, 12, 14)))
            {
                g.FillRectangle(bgBrush, 0, 0, modernDarkWindow.Width, titleH);
            }

            // Draw app icon
            if (File.Exists("app.png"))
            {
                using (Image appImg = Image.FromFile("app.png"))
                {
                    g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                    g.DrawImage(appImg, new Rectangle(11, 8, 18, 18));
                }
            }

            // Draw Window Title
            using (Font titleFont = new Font("Microsoft YaHei UI", 9F, FontStyle.Regular))
            using (SolidBrush textBrush = new SolidBrush(Color.FromArgb(235, 235, 235)))
            {
                g.DrawString("FerrisPulse · 灵脉", titleFont, textBrush, 36, 8);
            }

            // Draw Win11 Window Controls (- □ ✕)
            int btnW = 46;
            int rightX = modernDarkWindow.Width;
            using (Pen pen = new Pen(Color.FromArgb(200, 200, 200), 1.0f))
            {
                // Minimize (-)
                int minX = rightX - btnW * 3 + 18;
                g.DrawLine(pen, minX, 17, minX + 10, 17);

                // Maximize (□)
                int maxX = rightX - btnW * 2 + 18;
                g.DrawRectangle(pen, maxX, 12, 10, 10);

                // Close (✕)
                int closeX = rightX - btnW + 18;
                g.DrawLine(pen, closeX, 12, closeX + 10, 22);
                g.DrawLine(pen, closeX + 10, 12, closeX, 22);
            }

            // Draw client area
            g.DrawImage(clientOnly, 0, titleH);
        }

        modernDarkWindow.Save(@"promo\dist\test_modern_dark_window.png", ImageFormat.Png);
        Console.WriteLine("Saved test_modern_dark_window.png");

        form.Close();
    }
}
