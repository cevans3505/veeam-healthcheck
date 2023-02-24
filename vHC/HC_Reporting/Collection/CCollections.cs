﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Controls;
using System.Windows;
using VeeamHealthCheck.Collection.DB;
using VeeamHealthCheck.Security;
using VeeamHealthCheck.Shared;
using Microsoft.Management.Infrastructure;
using VeeamHealthCheck.DB;

namespace VeeamHealthCheck.Collection
{
    internal class CCollections
    {
        public CCollections() { }
        /* All collection utilities should run through here:
         * - powershell
         * - SQL
         * - Logs
         * - Other?
         * 
         */
        public void Run()
        {
            ExecPSScripts();
            if (!CGlobals.RunSecReport)
                PopulateWaits();

            ExecVmcReader();
            GetRegistryDbInfo();
            if(CGlobals.DBTYPE != CGlobals.PgTypeName)
                ExecSqlQueries();
            if(CGlobals.RunSecReport)
                ExecSecurityCollection();
            // do sql collections
        }

        private void ExecSecurityCollection()
        {
            CSecurityInit securityInit = new CSecurityInit();
            securityInit.Run();
        }
        private void ExecVmcReader()
        {
            if (CGlobals.IsVbr)
            {
                Collection.LogParser.CLogOptions logOptions = new("vbr");

            }
            if (CGlobals.IsVb365)
            {
                Collection.LogParser.CLogOptions logOptions = new("vb365");
            }
        }
        private void GetRegistryDbInfo()
        {
            CRegReader reg = new CRegReader();
            reg.GetDbInfo();
        }
        private void ExecSqlQueries()
        {
            CSqlExecutor sql = new();
            sql.Run();
        }
        private void ExecPSScripts()
        {
            CGlobals.Logger.Info("Starting PS Invoke", false);
            PSInvoker p = new PSInvoker();

            if (!CGlobals.RunSecReport)
            {
                try
                {
                    ExecVbrScripts(p);
                    ExecVb365Scripts(p);
                }
                catch (Exception ex)
                {
                    CGlobals.Logger.Error(ex.Message);
                }
            }
            else if (CGlobals.RunSecReport)
            {
                ExecVbrConfigOnly(p);
            }


            CGlobals.Logger.Info("Starting PS Invoke...done!", false);
        }
        private void ExecVbrScripts(PSInvoker p)
        {
            if (CGlobals.IsVbr)
            {
                CGlobals.Logger.Info("Entering vbr ps invoker", false);
                p.Invoke();
            }
        }
        private void ExecVbrConfigOnly(PSInvoker p)
        {
            CGlobals.Logger.Info("Entering vbr config collection");
            p.RunVbrConfigCollect();
        }
        private void ExecVb365Scripts(PSInvoker p)
        {
            if (CGlobals.IsVb365)
            {
                CGlobals.Logger.Info("Entering vb365 ps invoker", false);
                p.InvokeVb365Collect();
            }
        }
        private void PopulateWaits()
        {
            try
            {
                FilesParser.CLogParser lp = new();
                lp.GetWaitsFromFiles();
            }
            catch (Exception e)
            {
                CGlobals.Logger.Error("Error checking log files:");
                CGlobals.Logger.Error(e.Message);
            }

        }
    }
}
