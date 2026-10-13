using System;
using System.IO;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

class TestRapooCmdBrute
{
    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    static extern IntPtr CreateFile(string lpFileName, uint dwDesiredAccess, uint dwShareMode, IntPtr lpSecurityAttributes, uint dwCreationDisposition, uint dwFlagsAndAttributes, IntPtr hTemplateFile);

    [DllImport("hid.dll", SetLastError = true)]
    static extern bool HidD_SetOutputReport(IntPtr HidDeviceObject, byte[] lpReportBuffer, int ReportBufferLength);

    const uint GENERIC_READ = 0x80000000;
    const uint GENERIC_WRITE = 0x40000000;
    const uint FILE_SHARE_READ = 1;
    const uint FILE_SHARE_WRITE = 2;
    const uint OPEN_EXISTING = 3;
    const uint FILE_FLAG_OVERLAPPED = 0x40000000;

    static void Main()
    {
        string devicePath = @"\\?\hid#vid_24ae&pid_1413&mi_01&col09#8&376d1199&0&0008#{4d1e55b2-f16f-11cf-88cb-001111000030}";
        IntPtr h = CreateFile(devicePath, GENERIC_READ | GENERIC_WRITE, FILE_SHARE_READ | FILE_SHARE_WRITE, IntPtr.Zero, OPEN_EXISTING, FILE_FLAG_OVERLAPPED, IntPtr.Zero);
        if (h == IntPtr.Zero || h.ToInt64() == -1)
        {
            Console.WriteLine("CreateFile failed: " + Marshal.GetLastWin32Error());
            return;
        }

        SafeFileHandle sfh = new SafeFileHandle(h, true);
        using (FileStream fs = new FileStream(sfh, FileAccess.ReadWrite, 19, true))
        {
            byte[] cmd1List = new byte[] { 0x10, 0x11, 0x12, 0x13, 0x01, 0x02, 0x03, 0x04, 0x05, 0x20, 0x30, 0x40, 0x50, 0x60, 0x80, 0xA0 };
            byte[] cmd2List = new byte[] { 0x00, 0x01, 0x02, 0x03, 0x04, 0x05 };

            foreach (byte c1 in cmd1List)
            {
                foreach (byte c2 in cmd2List)
                {
                    byte[] req = new byte[19];
                    req[0] = 0x07;
                    req[1] = c1;
                    req[2] = c2;
                    int sum = 0;
                    for (int i = 0; i < 18; i++) sum += req[i];
                    req[18] = (byte)(sum & 0xFF);

                    byte[] buf = new byte[19];
                    IAsyncResult ar = fs.BeginRead(buf, 0, buf.Length, null, null);
                    bool ok = HidD_SetOutputReport(h, req, req.Length);

                    if (ar.AsyncWaitHandle.WaitOne(100))
                    {
                        int r = fs.EndRead(ar);
                        Console.WriteLine(string.Format("SUCCESS cmd [0x{0:X2}, 0x{1:X2}] -> Response: {2}", c1, c2, BitConverter.ToString(buf, 0, r)));
                    }
                    else
                    {
                        // cancel read
                        try { fs.EndRead(ar); } catch { }
                    }
                }
            }
        }
        Console.WriteLine("Scan complete.");
    }
}
