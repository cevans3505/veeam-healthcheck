﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection.Metadata;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
//using VeeamHealthCheck.Reporting.vsac;
using VeeamHealthCheck.Shared;

namespace VeeamHealthCheck.Resources
{
    internal class CArgsParser
    {
        [DllImport("kernel32.dll")]
        static extern IntPtr GetConsoleWindow();

        [DllImport("user32.dll")]
        static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        const int SW_HIDE = 0;
        const int SW_SHOW = 5;

        private readonly string[] _args;
        private CClientFunctions functions = new();
        public CArgsParser(string[] args)
        {
            _args = args;
            CGlobals.TOOLSTART = DateTime.Now;
        }
        public void ParseArgs()
        {
            //CGlobals.RunFullReport = true;
            LogInitialInfo();

            if (_args.Length == 0)
                ParseZeroArgs();
            else if (_args != null && _args.Length > 0)
                ParseAllArgs(_args);
            else
                LaunchUi(Handle(), true);
        }
        private void LogInitialInfo()
        {
            CClientFunctions f = new CClientFunctions();
            f.LogVersionAndArgs(_args);
            f.Dispose();
        }
        private void LaunchUi(IntPtr handle, bool hide)
        {
            CGlobals.Logger.Info("Executing GUI", false);
            if (hide)
                ShowWindow(handle, SW_HIDE);
            var app = new System.Windows.Application();
            app.Run(new VhcGui());
        }
        private IntPtr Handle()
        {
            return GetConsoleWindow();
        }

        private void ParseZeroArgs()
        {
            var pos = Console.GetCursorPosition();
            if (pos == (0, 0))
            {
                CGlobals.Logger.Info("0s");
                LaunchUi(Handle(), true);
            }
            if (pos != (0, 0))
            {
                CGlobals.Logger.Info("not 0");
                Console.WriteLine(CMessages.helpMenu);
            }
        }
        private void ParseAllArgs(string[] args)
        {
            bool run = false;
            bool ui = false;
            string targetDir = @"C:\temp\vHC";
            foreach (var a in args)
            {
                switch (a)
                {
                    case "/help":
                        CGlobals.Logger.Info("entering help menu", false);
                        Console.WriteLine(CMessages.helpMenu);
                        break;
                    case "/run":
                        run = true;
                        CGlobals.RunFullReport = true;
                        CGlobals.Logger.Info("Run = true");
                        break;
                    case "/show:files":
                        CGlobals.OpenExplorer = true;
                        break;
                    case "/show:report":
                        CGlobals.OpenHtml = true;
                        break;
                    case "/show:all":
                        break;
                    case "/days:7":
                        CGlobals.Logger.Info("Days set to 7");
                        CGlobals.ReportDays = 7;
                        break;
                    case "/days:30":
                        CGlobals.Logger.Info("Days set to 30");
                        CGlobals.ReportDays = 30;
                        break;
                    case "/days:90":
                        CGlobals.Logger.Info("Days set to 90");
                        CGlobals.ReportDays = 90;
                        break;
                    case "/days:12":
                        CGlobals.Logger.Info("Days set to 12");
                        CGlobals.ReportDays = 12;
                        break;
                    case "/gui":
                        CGlobals.RunFullReport = true;
                        ui = true;
                        break;
                    case "/import":
                        CGlobals.IMPORT = true;
                        break;
                    case "/security":
                        CGlobals.RunSecReport= true;
                        break;
                    //case var match when new Regex("outdir:.*").IsMatch(a):
                    //    string[] outputDir = a.Split(":");
                    //    targetDir = outputDir[1];
                    //    CGlobals.Logger.Info("Output directory: " + targetDir);
                    //    break;
                }
            }

            //if (CGlobals.RunSecReport)
            //{
            //    functions.RunSecurityReport();
            //}

            if (ui)
                LaunchUi(Handle(), false);
            else
            {
                functions.ModeCheck();
                FullRun(targetDir);

            }
            // if (CGlobals.RunFullReport)
            //{
            //    FullRun(targetDir);
            //}
            //else if (CGlobals.IMPORT)
            //{
            //    ImportRun(targetDir);
            //}
        }
        private void Run(string targetDir)
        {
            CClientFunctions functions = new();
            functions.CliRun(targetDir);
        }
        private void FullRun(string targetDir)
        {
            CGlobals.Logger.Info("Starting RUN...", false);
            Run(targetDir);


            CGlobals.Logger.Info("Starting RUN...complete!", false);
            CGlobals.Logger.Info("Output is stored in " + targetDir);

        }
        private void ImportRun(string targetDir)
        {
            CGlobals.Logger.Info("Starting IMPORT...", false);
            Run(targetDir);


            CGlobals.Logger.Info("Starting IMPORT...complete!", false);
            CGlobals.Logger.Info("Output is stored in " + targetDir);
        }
    }
}
