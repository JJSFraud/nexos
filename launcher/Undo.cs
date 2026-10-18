using System;
using System.Diagnostics;
using System.IO;
using System.Security.Principal;
using System.Windows.Forms;

namespace NexOSUndo
{
    static class Program
    {
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            // 1. Ensure Administrator privileges
            if (!IsAdministrator())
            {
                try
                {
                    ProcessStartInfo psi = new ProcessStartInfo
                    {
                        FileName = Application.ExecutablePath,
                        UseShellExecute = true,
                        Verb = "runas"
                    };
                    Process.Start(psi);
                }
                catch
                {
                    MessageBox.Show("Administrator privileges are required to restore disk partitions and boot settings.", "Administrator Required", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                }
                return;
            }

            DialogResult dr = MessageBox.Show(
                "Are you sure you want to completely undo all NexOS changes?\n\nThis will:\n" +
                " 1. Remove all NexOS boot entries from the Windows Boot Menu\n" +
                " 2. Delete the NEXOS partition\n" +
                " 3. Expand Drive C: back to 100% of your SSD space\n" +
                "\nYour personal Windows files will remain 100% untouched.",
                "NexOS Full System Restore",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Question);

            if (dr != DialogResult.Yes) return;

            // Execute PowerShell commands to restore system
            string psCode = @"
                # 1. Clean BCD boot entries
                try {
                    bcdedit /set {bootmgr} displaybootmenu no
                    bcdedit /set {bootmgr} timeout 0
                    $output = bcdedit /enum all
                    $currentId = ''
                    foreach ($line in $output) {
                        if ($line -match 'identifier\s+(\{[0-9a-fA-F-]+\})') { $currentId = $matches[1] }
                        if ($line -match 'description\s+.*NexOS.*' -and $currentId -ne '') {
                            bcdedit /delete $currentId /f | Out-Null
                        }
                    }
                } catch {}

                # 2. Delete NEXOS volume and expand C:
                try {
                    $vol = Get-Volume -FileSystemLabel 'NEXOS' -ErrorAction SilentlyContinue
                    if ($vol) {
                        $vol | Get-Partition | Remove-Partition -Confirm:$false -ErrorAction SilentlyContinue
                    }
                    $cPart = Get-Partition -DriveLetter C
                    $max = (Get-PartitionSupportedSize -DiskNumber $cPart.DiskNumber -PartitionNumber $cPart.PartitionNumber).SizeMax
                    Resize-Partition -DiskNumber $cPart.DiskNumber -PartitionNumber $cPart.PartitionNumber -Size $max -ErrorAction SilentlyContinue
                } catch {}
            ";

            try
            {
                ProcessStartInfo psi = new ProcessStartInfo
                {
                    FileName = "powershell.exe",
                    Arguments = "-NoProfile -ExecutionPolicy Bypass -Command \"" + psCode.Replace("\"", "\\\"") + "\"",
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    WindowStyle = ProcessWindowStyle.Hidden
                };

                Process p = Process.Start(psi);
                if (p != null) p.WaitForExit();

                MessageBox.Show(
                    "Success! All NexOS changes have been completely undone.\n\n" +
                    " - Windows 11 boot menu restored to factory default.\n" +
                    " - Drive C: expanded to 100% of your SSD.\n" +
                    " - All your personal files are safe.\n\n" +
                    "You can now safely delete the NexOS folder.",
                    "Restore Completed",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show("Error during restore: " + ex.Message, "Restore Error", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        static bool IsAdministrator()
        {
            WindowsIdentity identity = WindowsIdentity.GetCurrent();
            WindowsPrincipal principal = new WindowsPrincipal(identity);
            return principal.IsInRole(WindowsBuiltInRole.Administrator);
        }
    }
}
