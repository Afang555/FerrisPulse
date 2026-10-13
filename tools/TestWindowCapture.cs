using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;
using RazerBatteryTray;

class TestWindowCapture
{
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();

    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdcBlt, uint nFlags);

    private const uint PW_CLIENTONLY = 1;
    private const uint PW_RENDERFULLCONTENT = 2;

    [STAThread]
    static void Main()
    {
        SetProcessDPIAware();

        MainForm form = new MainForm();
        form.StartPosition = FormStartPosition.Manual;
        form.Location = new Point(100, 100);
        form.Show();
        Application.DoEvents();
        Thread.Sleep(500);

        // Test PrintWindow with flags 0, 1, 2
        uint[] flags = new uint[] { 0, 2 };
        foreach (uint flag in flags)
        {
            try
            {
                using (Bitmap bmp = new Bitmap(form.Width, form.Height))
                {
                    using (Graphics g = Graphics.FromImage(bmp))
                    {
                        IntPtr hdc = g.GetHdc();
                        bool ok = PrintWindow(form.Handle, hdc, flag);
                        g.ReleaseHdc(hdc);
                        Console.WriteLine("PrintWindow flag " + flag + " returned: " + ok);
                    }
                    bmp.Save(@"promo\dist\test_pw_" + flag + ".png", ImageFormat.Png);
                    Console.WriteLine("Saved test_pw_" + flag + ".png");
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine("Error flag " + flag + ": " + ex.Message);
            }
        }

        form.Close();
    }
}
