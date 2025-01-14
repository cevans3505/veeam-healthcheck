﻿// Copyright (c) 2021, Adam Congdon <adam.congdon2@gmail.com>
// MIT License
using System;
using System.Diagnostics;
using System.IO;
//using System.Management.Automation;
using System.Runtime.InteropServices;
using VeeamHealthCheck.Shared;
using VeeamHealthCheck.Shared.Logging;

namespace VeeamHealthCheck
{
    class PSInvoker
    {
        private readonly string _vb365Script = Environment.CurrentDirectory + @"\Tools\Scripts\Collect-VB365Data.ps1";
        private readonly string _vbrConfigScript = Environment.CurrentDirectory + @"\Tools\Scripts\Get-VBRConfig.ps1";
        private readonly string _vbrSessionScript = Environment.CurrentDirectory + @"\Tools\Scripts\Get-VeeamSessionReport.ps1";
        private readonly string _exportLogsScript = Environment.CurrentDirectory + @"\Tools\Scripts\Collect-VBRLogs.ps1";
        private readonly string _dumpServers= Environment.CurrentDirectory + @"\Tools\Scripts\DumpManagedServerToText.ps1";
        public static readonly string SERVERLISTFILE = "serverlist.txt";

        private readonly CLogger log = CGlobals.Logger;
        private readonly string logStart = "[PsInvoker]\t";
        public PSInvoker()
        {
        }
        public void Invoke()
        {
            TryUnblockFiles();

            //RunVbrVhcFunctionSetter();
            RunVbrConfigCollect();
            RunVbrSessionCollection();
        }
        public void TryUnblockFiles()
        {
            UnblockFile(_vbrConfigScript);
            UnblockFile(_vbrSessionScript);
            UnblockFile(_exportLogsScript);
            UnblockFile(_dumpServers);
            UnblockFile(_vb365Script);
        }
        public void RunVbrConfigCollect()
        {
            var res1 = Process.Start(VbrConfigStartInfo());
            log.Info(CMessages.PsVbrConfigProcId + res1.Id.ToString(), false);

            res1.WaitForExit();

            log.Info(CMessages.PsVbrConfigProcIdDone, false);
        }
        private ProcessStartInfo VbrConfigStartInfo()
        {
            log.Info(CMessages.PsVbrConfigStart, false);
            return ConfigStartInfo(_vbrConfigScript, 0, "");
        }

        private ProcessStartInfo ExportLogsStartInfo(string path, string server)
        {
            log.Info(CMessages.PsVbrConfigStart, false);
            return LogCollectionInfo(_exportLogsScript, path, server);
        }
        private ProcessStartInfo DumpServersStartInfo()
        {
            log.Info("Starting dump servers script", false);
            return ServerDumpInfo(_dumpServers);
        }
        public void RunServerDump()
        {
            ProcessStartInfo p = DumpServersStartInfo();
            var result = Process.Start(p);
            log.Info("Starting PowerShell Server Dump. Process ID: " + result.Id.ToString(), false);
            result.WaitForExit();
            log.Info("Powershell server dump complete.", false);
        }
        public void RunVbrLogCollect(string path, string server)
        {
            ProcessStartInfo p = ExportLogsStartInfo(path, server);
            //log.Debug(p., false);
            var res1 = Process.Start(p);
            log.Info(CMessages.PsVbrConfigProcId + res1.Id.ToString(), false);
            log.Info("\tPS Window is minimized by default. Progress indicators can be found there.", false);


            res1.WaitForExit();

            log.Info(CMessages.PsVbrConfigProcIdDone, false);
        }
        private ProcessStartInfo LogCollectionInfo(string scriptLocation, string path, string server)
        {
            string argString;
            argString = $"-NoProfile -ExecutionPolicy unrestricted -file {scriptLocation} -Server {server} -ReportPath {path}";

            //string argString = $"-NoProfile -ExecutionPolicy unrestricted -file \"{scriptLocation}\" -ReportPath \"{path}\"";
            log.Debug(logStart + "PS ArgString = " + argString, false);
            return new ProcessStartInfo()
            {
                FileName = "powershell.exe",
                Arguments = argString,
                UseShellExecute = true,
                CreateNoWindow = false,
                WindowStyle = ProcessWindowStyle.Minimized
            };
        }
        private ProcessStartInfo ServerDumpInfo(string scriptLocation)
        {
            string argString;
            argString = $"-NoProfile -ExecutionPolicy unrestricted -file \"{scriptLocation}\"";

            //string argString = $"-NoProfile -ExecutionPolicy unrestricted -file \"{scriptLocation}\" -ReportPath \"{path}\"";
            log.Debug(logStart + "PS ArgString = " + argString, false);
            return new ProcessStartInfo()
            {
                FileName = "powershell.exe",
                Arguments = argString,
                UseShellExecute = true,
                CreateNoWindow = false,
                WindowStyle = ProcessWindowStyle.Minimized
            };
        }

        private void RunVbrSessionCollection()
        {
            log.Info("[PS][VBR Sessions] Enter Session Collection Invoker...", false);


            var startInfo2 = ConfigStartInfo(_vbrSessionScript, CGlobals.ReportDays, "");


            log.Info("[PS][VBR Sessions] Starting Session Collection PowerShell Process...", false);

            var result = Process.Start(startInfo2);

            log.Info("[PS][VBR Sessions] Process started with ID: " + result.Id.ToString(), false);
            result.WaitForExit();

            log.Info("[PS][VBR Sessions] Session collection complete!", false);
        }
        private ProcessStartInfo ConfigStartInfo(string scriptLocation, int days, string path)
        {
            if (CGlobals.REMOTEHOST == "")
                CGlobals.REMOTEHOST = "localhost";
            string argString;
            if (days != 0)
                argString = $"-NoProfile -ExecutionPolicy unrestricted -file \"{scriptLocation}\" -VBRServer \"{CGlobals.REMOTEHOST}\" -ReportInterval {CGlobals.ReportDays} ";
            else
                argString = $"-NoProfile -ExecutionPolicy unrestricted -file \"{scriptLocation}\" -VBRServer \"{CGlobals.REMOTEHOST}\" -VBRVersion \"{CGlobals.VBRMAJORVERSION}\" ";
            if (!String.IsNullOrEmpty(path))
            {
                argString = $"-NoProfile -ExecutionPolicy unrestricted -file \"{scriptLocation}\" -ReportPath \"{path}\"";
            }
            //log.Debug(logStart + "PS ArgString = " + argString, false);
            return new ProcessStartInfo()
            {
                FileName = "powershell.exe",
                Arguments = argString,
                UseShellExecute = false,
                CreateNoWindow = true  //true for prod
            };
        }

        public void InvokeVb365Collect()
        {
            log.Info("[PS] Enter VB365 collection invoker...", false);
            var scriptFile = _vb365Script;
            UnblockFile(scriptFile);

            var startInfo = new ProcessStartInfo()
            {
                FileName = "powershell.exe",
                Arguments = $"-NoProfile -ExecutionPolicy unrestricted -file \"{scriptFile}\" -ReportingIntervalDays \"{CGlobals.ReportDays}\"",
                UseShellExecute = false,
                CreateNoWindow = true
            };
            log.Info("[PS] Starting VB365 Collection Powershell process", false);
            log.Info("[PS] [ARGS]: " + startInfo.Arguments, false);
            var result = Process.Start(startInfo);
            log.Info("[PS] Process started with ID: " + result.Id.ToString(), false);
            result.WaitForExit();
            log.Info("[PS] VB365 collection complete!", false);

        }
        private ProcessStartInfo psInfo(string scriptFile)
        {
            return new ProcessStartInfo()
            {
                FileName = "powershell.exe",
                Arguments = $"",
                UseShellExecute = false,
                CreateNoWindow = true
            };
        }
        private string Vb365ScriptFile()
        {
            string[] script = Directory.GetFiles(_vb365Script);
            return script[0];
        }
        private void UnblockFile(string file)
        {
            try
            {
                FileUnblocker fu = new();
                fu.Unblock(file);
            }
            catch (Exception ex)
            {
                log.Warning("Script unblock failed. Manual unblocking of files may be required.\n\t");
                log.Warning(ex.Message);
            }

        }
    }
    public class FileUnblocker
    {
        [DllImport("kernel32", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool DeleteFile(string name);

        public bool Unblock(string fileName)
        {
            return DeleteFile(fileName + ":Zone.Identifier");
        }
    }
}
