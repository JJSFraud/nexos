using System;
using System.Diagnostics;
using System.IO;

namespace NexOS
{
    class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            try
            {
                string scriptDir = AppDomain.CurrentDomain.BaseDirectory;
                string psScript = Path.Combine(scriptDir, "NexOS-Launcher.ps1");

                if (!File.Exists(psScript))
                {
                    psScript = Path.Combine(scriptDir, "..", "launcher", "NexOS-Launcher.ps1");
                }

                ProcessStartInfo psi = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File \"" + psScript + "\"",
                    UseShellExecute = false,
                    CreateNoWindow = true
                };

                Process proc = Process.Start(psi);
                if (proc != null)
                {
                    proc.WaitForExit();
                }
            }
            catch (Exception ex)
            {
                System.Windows.Forms.MessageBox.Show("Error starting NexOS Launcher: " + ex.Message, "NexOS Launcher", System.Windows.Forms.MessageBoxButtons.OK, System.Windows.Forms.MessageBoxIcon.Error);
            }
        }
    }
}
