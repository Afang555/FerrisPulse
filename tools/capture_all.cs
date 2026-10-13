using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Windows.Forms;
using System.Threading;
using System.Reflection;

class CaptureAll
{
    [STAThread]
    static void Main()
    {
        Assembly asm = Assembly.LoadFrom("RazerBatteryTray.exe");
        Type formType = asm.GetType("RazerBatteryTray.MainForm");
        Form form = (Form)Activator.CreateInstance(formType);

        // 1. Show and capture main form
        form.Show();
        Application.DoEvents();
        Thread.Sleep(300);
        Application.DoEvents();

        Bitmap bmpForm = new Bitmap(form.Width, form.Height);
        form.DrawToBitmap(bmpForm, new Rectangle(0, 0, form.Width, form.Height));
        bmpForm.Save("actual_runtime_form.png", ImageFormat.Png);
        Console.WriteLine("Saved actual_runtime_form.png");

        // 2. Capture context menu
        FieldInfo cmField = formType.GetField("contextMenu", BindingFlags.NonPublic | BindingFlags.Instance);
        ContextMenuStrip cm = (ContextMenuStrip)cmField.GetValue(form);

        FieldInfo dpiField = formType.GetField("dpiMenu", BindingFlags.NonPublic | BindingFlags.Instance);
        ToolStripMenuItem dpiMenu = (ToolStripMenuItem)dpiField.GetValue(form);

        cm.Show(0, 0);
        Application.DoEvents();

        Bitmap bmpMenu = new Bitmap(cm.Width, cm.Height);
        cm.DrawToBitmap(bmpMenu, new Rectangle(0, 0, cm.Width, cm.Height));
        bmpMenu.Save("actual_tray_menu_v4.png", ImageFormat.Png);
        Console.WriteLine("Saved actual_tray_menu_v4.png");

        // 3. Capture DPI submenu
        dpiMenu.DropDown.Show(cm.Right, cm.Top + 60);
        Application.DoEvents();
        Bitmap bmpDpi = new Bitmap(dpiMenu.DropDown.Width, dpiMenu.DropDown.Height);
        dpiMenu.DropDown.DrawToBitmap(bmpDpi, new Rectangle(0, 0, dpiMenu.DropDown.Width, dpiMenu.DropDown.Height));
        bmpDpi.Save("actual_dpi_submenu_v4.png", ImageFormat.Png);
        Console.WriteLine("Saved actual_dpi_submenu_v4.png");

        // 4. Capture OSD
        FieldInfo osdField = formType.GetField("osdForm", BindingFlags.NonPublic | BindingFlags.Instance);
        Form osdForm = (Form)osdField.GetValue(form);
        MethodInfo showDpiMethod = osdForm.GetType().GetMethod("ShowDpi");
        showDpiMethod.Invoke(osdForm, new object[] { 3000, 4, 5 });

        Application.DoEvents();
        Thread.Sleep(200);
        Application.DoEvents();

        Bitmap bmpOsd = new Bitmap(osdForm.Width, osdForm.Height);
        osdForm.DrawToBitmap(bmpOsd, new Rectangle(0, 0, osdForm.Width, osdForm.Height));
        bmpOsd.Save("actual_osd_v4.png", ImageFormat.Png);
        Console.WriteLine("Saved actual_osd_v4.png");

        // 5. Capture Tray icon bitmaps (Capsule and NumberBadge)
        MethodInfo drawTrayMethod = formType.GetMethod("DrawTrayBitmap", BindingFlags.NonPublic | BindingFlags.Static);
        if (drawTrayMethod != null)
        {
            Bitmap trayCapsule = (Bitmap)drawTrayMethod.Invoke(null, new object[] { 100, false, true, 0, 24 });
            trayCapsule.Save("actual_tray_capsule_24.png", ImageFormat.Png);
            Bitmap trayNum = (Bitmap)drawTrayMethod.Invoke(null, new object[] { 100, false, true, 1, 24 });
            trayNum.Save("actual_tray_num_24.png", ImageFormat.Png);
            Console.WriteLine("Saved actual tray bitmaps");
        }

        osdForm.Close();
        form.Close();
    }
}
