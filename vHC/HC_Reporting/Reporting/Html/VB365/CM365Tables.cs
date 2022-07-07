﻿using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using VeeamHealthCheck.CsvHandlers;
using VeeamHealthCheck.Reporting.Html.Shared;
using VeeamHealthCheck.Resources.Localization.VB365;

namespace VeeamHealthCheck.Reporting.Html.VB365
{
    internal class CM365Tables
    {
        private CHtmlFormatting _form = new();
        private CCsvParser _csv = new(CVariables.vb365dir);
        private CM365Summaries _summary = new CM365Summaries();
        private Scrubber.CScrubHandler _scrubber = new();
        public CM365Tables()
        {

        }
        public string Globals()
        {
            string s = "<div class=\"global\" id=\"global\">";
            s += _form.header2("Global Configuration");
            s += "<br>";
            s += "<table border=\"1\"><tr>";
            s += _form.TableHeader(Vb365ResourceHandler.GlobalColHeadLicStatus, "License Status");
            s += _form.TableHeader(Vb365ResourceHandler.GlobalColHeadLicExp, "License Expiry");
            s += _form.TableHeader(Vb365ResourceHandler.GlobalColHeadSupExp, "Support Expiry");
            s += _form.TableHeader(Vb365ResourceHandler.GlobalColHeadLicType, "License Type");
            s += _form.TableHeader(Vb365ResourceHandler.GlobalColHeadLicTo, "Licensed To");
            s += _form.TableHeader(Vb365ResourceHandler.GlobalColHeadLicContact, "License Contact");
            s += _form.TableHeader(Vb365ResourceHandler.GlobalColHeadLicFor, "Licensed For");
            s += _form.TableHeader(Vb365ResourceHandler.GlobalColHeadLicUsed, "Licenses Used");
            s += _form.TableHeader(Vb365ResourceHandler.GlobalColHeadGFolderExcl, Vb365ResourceHandler.GlobalFolderExclTT);
            s += _form.TableHeader(Vb365ResourceHandler.GlobalColHeadGRetExcl, Vb365ResourceHandler.GlobalRetExclTT);
            s += _form.TableHeader(Vb365ResourceHandler.GlobalColHeadSessHisRet, Vb365ResourceHandler.GlobalLogRetTT);
            s += _form.TableHeader(Vb365ResourceHandler.GlobalColHeadNotifyEnabled, Vb365ResourceHandler.GlobalNotificationEnabledTT);
            s += _form.TableHeader(Vb365ResourceHandler.GlobalColHeadNotifyOn, Vb365ResourceHandler.GlobalNotifyOnTT);
            s += _form.TableHeader(Vb365ResourceHandler.GlobalColHeadAutoUpdate, "Automatic Updates?");
            s += "</tr>";

            var global = _csv.GetDynamicVboGlobal();
            s += "<tr>";
            foreach (var gl in global)
            {
                //parse lic to int:
                decimal.TryParse(gl.LicensedFor, out decimal licFor);
                decimal.TryParse(gl.LicensesUsed, out decimal licUsed);
                decimal percentUsed = licUsed / licFor * 100;
                

                s += _form.TableData(gl.LicenseStatus, "");
                s += _form.TableData(gl.LicenseExpiry, "");
                s += _form.TableData(gl.SupportExpiry, "");
                s += _form.TableData(gl.LicenseType, "");
                s += _form.TableData(gl.LicensedTo, "");
                s += _form.TableData(gl.LicenseContact, "");
                s += _form.TableData(gl.LicensedFor, "");

                if(percentUsed > 95)
                    s += _form.TableData(gl.LicensesUsed, "", 1);
                else if(percentUsed > 90)
                    s += _form.TableData(gl.LicensesUsed, "", 2);
                else
                    s += _form.TableData(gl.LicensesUsed, "");

                s += _form.TableData(gl.GlobalFolderExclusions, "");
                s += _form.TableData(gl.GlobalRetExclusions, "");
                s += _form.TableData(gl.LogRetention, "");
                if(gl.NotificationEnabled == "False")
                    s += _form.TableData(gl.NotificationEnabled, "", 2);
                else
                    s += _form.TableData(gl.NotificationEnabled, "");

                s += _form.TableData(gl.NotififyOn, "");
                
                if(gl.AutomaticUpdates == "False")
                    s += _form.TableData(gl.AutomaticUpdates, "", 2);
                else
                    s += _form.TableData(gl.AutomaticUpdates, "");
            }
            s += "</tr></table>";

            // summary
            s += _summary.GlobalSummary();

            s += "</div>";
            return s;
        }
        public string Vb365Proxies()
        {
            string s = "<div class=\"proxies\" id=\"proxies\">";
            s += _form.header2("Proxies");
            s += "<br>";
            s += "<table border=\"1\"><tr>";
            s += _form.TableHeader("Proxy Name", "");
            s += _form.TableHeader("Description", "");
            s += _form.TableHeader("Threads", "");
            s += _form.TableHeader("Throttling", Vb365ResourceHandler.proxyTTThrottling);
            s += _form.TableHeader("State", Vb365ResourceHandler.proxyTTState);
            //s += _form.TableHeader("Type", "");
            s += _form.TableHeader("Outdated", Vb365ResourceHandler.proxyTTOutdated);
            s += _form.TableHeader("Internet Proxy", Vb365ResourceHandler.proxyTTInternet);
            s += _form.TableHeader("Objects Managed", Vb365ResourceHandler.proxyTTObjects);
            s += _form.TableHeader("OS Version", "");
            s += _form.TableHeader("RAM", "");
            s += _form.TableHeader("CPUs", Vb365ResourceHandler.proxyTTCPUs);
            s += _form.TableHeader("Extended Logging?", "");

            s += "</tr>";

            var global = _csv.GetDynamicVboProxies().ToList();
            foreach (var gl in global)
            {
                int counter = 0;

                s += "<tr>";

                foreach (var g in gl)
                {
                    if (g.Key == "type")
                    {
                        continue;
                    }
                    string output = g.Value;
                    if (VhcGui._scrub)
                    {
                        
                        if (counter == 0 || counter == 1)
                            output = _scrubber.ScrubItem(output);
                    }
                    s += _form.TableData(output, "");
                    counter++;

                }

                s += "</tr>";
            }
            s += "</table>";
            s += _summary.ProxySummary();

            s += "</div>";
            return s;
        }
        public string Vb365Repos()
        {
            string s = "<div class=\"repos\" id=\"repos\">";
            s += _form.header2("Repositories");
            s += "<br>";
            s += "<table border=\"1\"><tr>";
            s += _form.TableHeader(Vb365ResourceHandler.RepoColumn1, Vb365ResourceHandler.RepoColumnTT1);
            s += _form.TableHeader(Vb365ResourceHandler.RepoColumn2, Vb365ResourceHandler.RepoColumnTT2);
            s += _form.TableHeader(Vb365ResourceHandler.RepoColumn3, Vb365ResourceHandler.RepoColumnTT3);
            s += _form.TableHeader(Vb365ResourceHandler.RepoColumn4, Vb365ResourceHandler.RepoColumnTT4);
            s += _form.TableHeader(Vb365ResourceHandler.RepoColumn5, Vb365ResourceHandler.RepoColumnTT5);
            s += _form.TableHeader(Vb365ResourceHandler.RepoColumn6, Vb365ResourceHandler.RepoColumnTT6);
            s += _form.TableHeader(Vb365ResourceHandler.RepoColumn7, Vb365ResourceHandler.RepoColumnTT7);
            s += _form.TableHeader(Vb365ResourceHandler.RepoColumn8, Vb365ResourceHandler.RepoColumnTT8);
            s += _form.TableHeader(Vb365ResourceHandler.RepoColumn9, Vb365ResourceHandler.RepoColumnTT9);
            s += _form.TableHeader(Vb365ResourceHandler.RepoColumn10, Vb365ResourceHandler.RepoColumnTT10);
            s += _form.TableHeader(Vb365ResourceHandler.RepoColumn11, Vb365ResourceHandler.RepoColumnTT11);
            s += _form.TableHeader(Vb365ResourceHandler.RepoColumn12, Vb365ResourceHandler.RepoColumnTT12);
            s += _form.TableHeader(Vb365ResourceHandler.RepoColumn13, Vb365ResourceHandler.RepoColumnTT13);
            s += _form.TableHeader(Vb365ResourceHandler.RepoColumn14, Vb365ResourceHandler.RepoColumnTT14);

            s += "</tr>";

            var global = _csv.GetDynamicVboRepo().ToList();

            foreach (var g in global)
            {
                s += "<tr>";
                //int counter = 0;
                //string output = g.ToString();
                string boundProxy = g.BoundProxy;
                string name = g.Name;
                string desc = g.Description;
                string path = g.Path;
                string objRepo = g.ObjectRepo;


                if (VhcGui._scrub)
                {
                    boundProxy = _scrubber.ScrubItem(g.BoundProxy);
                    name = _scrubber.ScrubItem(g.Name);
                    desc = _scrubber.ScrubItem(g.Description);
                    path = _scrubber.ScrubItem(g.Path);
                    objRepo = _scrubber.ScrubItem(g.ObjectRepo);
                }
                s += _form.TableData(boundProxy, "");
                s += _form.TableData(name, "");
                s += _form.TableData(desc, "");
                s += _form.TableData(g.Type, "");
                s += _form.TableData(path, "");
                s += _form.TableData(objRepo, "");
                s += _form.TableData(g.Encryption, "");
                s += _form.TableData(g.State, "");
                s += _form.TableData(g.Capacity, "");
                s += _form.TableData(g.Free, "");
                s += _form.TableData(g.DataStored, "");
                s += _form.TableData(g.CacheSpaceUsed, "");
                s += _form.TableData(g.DailyChangeRate, "");
                s += _form.TableData(g.Retention, "");
                s += "</tr>";

            }

            s += "</table>";

            s += _summary.RepoSummary();
            s += "</div>";
            return s;
        }
        public string Vb365Rbac()
        {
            string s = "<div class=\"rbac\" id=\"rbac\">";
            s += _form.header2("RBAC Roles Info");
            s += "<br>";
            s += "<table border=\"1\"><tr>";
            s += _form.TableHeader("Name", "");
            s += _form.TableHeader("Description", "");
            s += _form.TableHeader("Role Type", "");
            s += _form.TableHeader("Operators", "");
            s += _form.TableHeader("Selected Items", "");
            s += _form.TableHeader("Excluded Items", "");

            s += "</tr>";

            var global = _csv.GetDynamicVboRbac().ToList();
            foreach (var gl in global)
            {
                s += "<tr>";

                int counter = 0;
                foreach (var g in gl)
                {
                    string output = g.Value;
                    if (VhcGui._scrub)
                    {
                        output = _scrubber.ScrubItem(output);
                    }
                    s += _form.TableData(output, "");
                    counter++;
                }

                s += "</tr>";
            }
            s += "</table>";

            s += _summary.RbacSummary();
            s += "</div>";
            return s;
        }
        public string Vb365Security()
        {
            string s = "<div class=\"sec\" id=\"sec\">";
            s += _form.header2("Security Info");
            s += "<br>";
            s += "<table border=\"1\"><tr>";
            s += _form.TableHeader(Vb365ResourceHandler.SecurityTableColumn1, "Win. Firewall Enabled?");
            s += _form.TableHeader(Vb365ResourceHandler.SecurityTableColumn2, "Internet proxy?");
            s += "</tr>";



            var global = _csv.GetDynamicVboSec().ToList();

            foreach (var g in global)
            {
                string apiCert = g.APICert;
                string serverCert = g.ServerCert;
                string tenantCert = g.TenantAuthCert;
                string portalCert = g.RestorePortalCert;


                if (VhcGui._scrub)
                {
                    apiCert = _scrubber.ScrubItem(apiCert);
                    serverCert = _scrubber.ScrubItem(serverCert);
                    tenantCert = _scrubber.ScrubItem(tenantCert);
                    portalCert = _scrubber.ScrubItem(portalCert);
                }


                s += "<tr>";
                s += _form.TableData(g.WinFirewallEnabled, "");
                s += _form.TableData(g.Internetproxy, "");
                s += "</tr>";

                s += "</table><table border =\"1\"><tr><br/>";
                s += _form.TableHeader(Vb365ResourceHandler.SecurityTable2Column1, Vb365ResourceHandler.securityTTServices);
                s += _form.TableHeader(Vb365ResourceHandler.SecurityTable2Column2, "");
                s += _form.TableHeader(Vb365ResourceHandler.SecurityTable2Column3, Vb365ResourceHandler.securityTTPort);
                s += _form.TableHeader(Vb365ResourceHandler.SecurityTable2Column4, Vb365ResourceHandler.securityTTCert);
                s += _form.TableHeader(Vb365ResourceHandler.SecurityTable2Column5, "");
                s += _form.TableHeader(Vb365ResourceHandler.SecurityTable2Column6, "");
                s += "</tr><tr>";
                s += _form.TableData("Server", "");
                s += _form.TableData("", "");// enabled
                s += _form.TableData("", "");// port
                s += _form.TableData(serverCert, "");// cert
                s += _form.TableData(g.ServerCertExpires, "");// expires
                s += _form.TableData(g.ServerCertSelfSigned, "");// self signed
                s += "</tr><tr>";

                s += _form.TableData("API", "");
                s += _form.TableData(g.APIEnabled, "");
                s += _form.TableData(g.APIPort, "");
                s += _form.TableData(apiCert, "");
                s += _form.TableData(g.APICertExpires, "");
                s += _form.TableData(g.APICertSelfSigned, "");
                s += "</tr><tr>";
                s += _form.TableData("Tenant Auth", "");
                s += _form.TableData(g.TenantAuthEnabled, "");
                s += _form.TableData("", "");
                s += _form.TableData(tenantCert, "");
                s += _form.TableData(g.TenantAuthCertExpires, "");
                s += _form.TableData(g.TenantAuthCertSelfSigned, "");
                s += "</tr><tr>";
                s += _form.TableData("Restore Portal", "");
                s += _form.TableData(g.RestorePortalEnabled, "");
                s += _form.TableData("", "");
                s += _form.TableData(portalCert, "");
                s += _form.TableData(g.RestorePortalCertExpires, "");
                s += _form.TableData(g.RestorePortalCertSelfSigned, "");
                s += "</tr>";


            }


            s += "</table>";
            s += _summary.SecSummary();

            s += "</div>";
            return s;
        }
        public string Vb365Controllers()
        {
            string s = "<div class=\"controller\" id=\"controller\">";
            s += _form.header2("Backup Server");
            s += "<br>";
            s += "<table border=\"1\"><tr>";
            s += _form.TableHeader("VB365 Version", "VB365 Version");
            s += _form.TableHeader("OS Version", "OS Version");
            s += _form.TableHeader("RAM", "RAM");
            s += _form.TableHeader("CPUs", "CPUs");
            s += _form.TableHeader("Proxies Managed", "Proxies Managed");
            s += _form.TableHeader("Repos Managed", "Repos Managed");
            s += _form.TableHeader("Orgs Managed", "Orgs Managed");
            s += _form.TableHeader("Jobs Managed", "Jobs Managed");
            s += _form.TableHeader("PowerShell Installed?", "PowerShell Installed?");
            s += _form.TableHeader("Proxy Installed?", "Proxy Installed?");
            s += _form.TableHeader("REST Installed?", "REST Installed?");
            s += _form.TableHeader("Console Installed?", "Console Installed?");
            s += _form.TableHeader("VM Name", "VM Name");
            s += _form.TableHeader("VM Location", "VM Location");
            s += _form.TableHeader("VM SKU", "VM SKU");
            s += _form.TableHeader("VM Size", "VM Size");



            s += "</tr>";

            var global = _csv.GetDynVboController().ToList();
            foreach (var gl in global)
            {
                s += "<tr>";

                int counter = 0;
                foreach (var g in gl)
                {
                    string output = g.Value;
                    if (VhcGui._scrub)
                    {
                        if (counter == 12 || counter == 13)
                            output = _scrubber.ScrubItem(output);
                    }
                    s += _form.TableData(output, "");
                    counter++;
                }

                s += "</tr>";
            }
            s += "</table>";
            s += _summary.ControllerSummary();

            s += "</div>";
            return s;
        }
        public string Vb365ControllerDrives()
        {
            string s = "<div class=\"controllerdrives\" id=\"controllerdrives\">";
            s += _form.header2("Backup Server Disks");
            s += "<br>";
            s += "<table border=\"1\"><tr>";
            s += _form.TableHeader("Friendly Name", "Friendly Name");
            s += _form.TableHeader("DeviceId", Vb365ResourceHandler.BkpSrvDisksDeviceIdTT);
            s += _form.TableHeader("Bus Type", "Bus Type");
            s += _form.TableHeader("Media Type", "Media Type");
            s += _form.TableHeader("Manufacturer", "Manufacturer");
            s += _form.TableHeader("Model", "Model");
            s += _form.TableHeader("Size", "Size");
            s += _form.TableHeader("Allocated Size", "Allocated Size");
            s += _form.TableHeader("Operational Status", "Operational Status");
            s += _form.TableHeader("Health Status", "Health Status");
            s += _form.TableHeader("Boot Drive", "Boot Drive");

            s += "</tr>";

            var global = _csv.GetDynVboControllerDriver().ToList();
            foreach (var gl in global)
            {
                s += "<tr>";

                foreach (var g in gl)
                    s += _form.TableData(g.Value, "");

                s += "</tr>";
            }
            s += "</table>";

            s += _summary.ControllerDrivesSummary();
            s += "</div>";
            return s;
        }
        public string Vb365JobSessions()
        {
            string s = "<div class=\"jobsessions\" id=\"jobsessions\">";
            s += _form.header2("Job Sessions");
            //s += "<br>";
            s += _form.CollapsibleButton("Show Job Sessions");

            s += "<table border=\"1\" style=\"display: none;\"><tr>";
            s += _form.TableHeader("Name", "Name");
            s += _form.TableHeader("Status", "Status");
            s += _form.TableHeader("Start Time", "Start Time");
            s += _form.TableHeader("End Time", "End Time");
            s += _form.TableHeader("Duration", "Duration");
            s += _form.TableHeader("Log", "Log");

            s += "</tr>";

            var global = _csv.GetDynVboJobSess().ToList();
            foreach (var gl in global)
            {
                s += "<tr>";

                int counter = 0;
                foreach (var g in gl)
                {
                    string output = g.Value;
                    if (VhcGui._scrub)
                    {
                        if (counter == 0 || counter == 5)
                            output = _scrubber.ScrubItem(output);
                    }
                    s += _form.TableData(output, "");
                    counter++;
                }

                s += "</tr>";
            }
            s += "</table>";

            s += _summary.JobSessSummary();

            s += "</div>";
            return s;
        }
        public string Vb365ProcStats()
        {
            string s = "<div class=\"procstats\" id=\"procstats\">";
            s += _form.header2("Processing Statistics");
            //s += "<br>";
            s += _form.CollapsibleButton("Show Processing Stats");
            s += "<table border=\"1\" style=\"display: none;\"><tr>";
            s += _form.TableHeader("Name", "");
            s += _form.TableHeader("Operation", "");
            s += _form.TableHeader("Time (latest)", "");
            s += _form.TableHeader("Time (Median)", "");
            s += _form.TableHeader("Time (Min)", "");
            s += _form.TableHeader("Time (Avg)","");
            s += _form.TableHeader("Time (Max)", "");
            s += _form.TableHeader("Time (90%)", "");

            s += "</tr>";

            var global = _csv.GetDynamicVboProcStat().ToList();
            foreach (var gl in global)
            {
                s += "<tr>";

                int counter = 0;
                foreach (var g in gl)
                {
                    string output = g.Value;
                    s += _form.TableData(output, "");
                    counter++;
                }

                s += "</tr>";
            }
            s += "</table>";

            //s += _summary.JobStatSummary();
            s += "</div>";
            return s;
        }
        public string Vb365JobStats()
        {
            string s = "<div class=\"jobstats\" id=\"jobstats\">";
            s += _form.header2("Job Statistics");
            //s += "<br>";
            s += _form.CollapsibleButton("Show Job Stats");
            s += "<table border=\"1\" style=\"display: none;\"><tr>";
            s += _form.TableHeader("Name", "Name");
            s += _form.TableHeader("Average Duration (hh:mm:ss)", "Average Duration (hh:mm:ss)");
            s += _form.TableHeader("Max Duration (hh:mm:ss)", "Max Duration (hh:mm:ss)");
            s += _form.TableHeader("Average Data Transferred", "Average Data Transferred");
            s += _form.TableHeader("Max Data Transferred", "Max Data Transferred");
            s += _form.TableHeader("Average Objects (#)", "Average Objects (#)");
            s += _form.TableHeader("Max Objects (#)", "Max Objects (#)");
            s += _form.TableHeader("Average Items (#)", "Average Items (#)");
            s += _form.TableHeader("Max Items (#)", "Max Items (#)");
            s += _form.TableHeader("Typical Bottleneck", "Typical Bottleneck");
            s += _form.TableHeader("Job Avg Throughput", "Job Avg Throughput");
            s += _form.TableHeader("Job Avg Processing Rate", "Job Avg Processing Rate");

            s += "</tr>";

            var global = _csv.GetDynVboJobStats().ToList();
            foreach (var gl in global)
            {
                s += "<tr>";

                int counter = 0;
                foreach (var g in gl)
                {
                    string output = g.Value;
                    if (VhcGui._scrub)
                    {
                        if (counter == 0)
                            output = _scrubber.ScrubItem(output);
                    }
                    s += _form.TableData(output, "");
                    counter++;
                }

                s += "</tr>";
            }
            s += "</table>";

            s += _summary.JobStatSummary();
            s += "</div>";
            return s;
        }
        public string Vb365ObjectRepos()
        {
            string s = "<div class=\"objrepo\" id=\"objrepo\">";
            s += _form.header2("Object Storage");
            s += "<br>";
            s += "<table border=\"1\"><tr>";
            s += _form.TableHeader("Name", "Name");
            s += _form.TableHeader("Description", "Description");
            s += _form.TableHeader("Cloud", "Cloud");
            s += _form.TableHeader("Type", "Type");
            s += _form.TableHeader("Bucket/Container", "Bucket/Container");
            s += _form.TableHeader("Path", "Path");
            s += _form.TableHeader("Size Limit", "Size Limit");
            s += _form.TableHeader("Used Space", "Used Space");
            s += _form.TableHeader("Free Space", "Free Space");
            s += _form.TableHeader("Bound Repo", "Bound Repository");

            s += "</tr>";

            var global = _csv.GetDynVboObjRepo().ToList();
            foreach (var gl in global)
            {
                s += "<tr>";

                int counter = 0;
                foreach (var g in gl)
                {
                    string output = g.Value;
                    if (VhcGui._scrub)
                    {
                        if (counter == 0 ||
                            counter == 1 ||
                            counter == 4 ||
                            counter == 5)
                            output = _scrubber.ScrubItem(output);
                    }
                    s += _form.TableData(output, "");
                    counter++;
                }

                s += "</tr>";
            }
            s += "</table>";

            s += _summary.ObjRepoSummary();

            s += "</div>";
            return s;
        }
        public string Vb365Orgs()
        {
            string s = "<div class=\"orgs\" id=\"orgs\">";
            s += _form.header2("Organizations");
            s += "<br>";
            s += "<table border=\"1\"><tr>";
            s += _form.TableHeader("Friendly Name", "Friendly Name");
            s += _form.TableHeader("Real Name", "Real Name");
            s += _form.TableHeader("Type", "Type");
            s += _form.TableHeader("Protected Apps", "Protected Apps");
            s += _form.TableHeader("EXO Settings", Vb365ResourceHandler.orgTTEXOSettings);
            s += _form.TableHeader("EXO App Cert", Vb365ResourceHandler.orgTTEXOApp);
            s += _form.TableHeader("SPO Settings", Vb365ResourceHandler.orgTTSPOSettings);
            s += _form.TableHeader("SPO App Cert", Vb365ResourceHandler.orgTTSPOApp);
            s += _form.TableHeader("On-Prem Exch Settings", "On-Prem Exch Settings");
            s += _form.TableHeader("On-Prem SP Settings", "On-Prem SP Settings");
            s += _form.TableHeader("Licensed Users", "Licensed Users");
            s += _form.TableHeader("Grant SC Admin", "Grant SC Admin");
            s += _form.TableHeader("Aux Accounts/Apps", "Aux Accounts/Apps");

            s += "</tr>";

            var global = _csv.GetDynVboOrg().ToList();
            foreach (var gl in global)
            {
                s += "<tr>";

                int counter = 0;
                foreach (var g in gl)
                {
                    string output = g.Value;
                    if (VhcGui._scrub)
                    {
                        if (counter == 0 ||
                            counter == 1 ||
                            counter == 4 ||
                            counter == 5 ||
                            counter == 6 ||
                            counter == 8 ||
                            counter == 9)
                            output = _scrubber.ScrubItem(output);
                    }
                    s += _form.TableData(output, "");
                    counter++;
                }

                s += "</tr>";
            }
            s += "</table>";

            s += _summary.OrgSummary();
            s += "</div>";
            return s;
        }
        public string Vb365Permissions()
        {
            string s = "<div class=\"perms\" id=\"perms\">";
            s += _form.header2("Permissions Check");
            s += "<br>";
            s += "<table border=\"1\"><tr>";
            s += _form.TableHeader("Type", "Type");
            s += _form.TableHeader("Organization", "Organization");
            s += _form.TableHeader("API", "API");
            s += _form.TableHeader("Permission", "Permission");

            s += "</tr>";

            var global = _csv.GetDynVboPerms().ToList();
            foreach (var gl in global)
            {
                s += "<tr>";

                int counter = 0;
                foreach (var g in gl)
                {
                    string output = g.Value;
                    if (VhcGui._scrub)
                    {
                        if (counter == 1)
                            output = _scrubber.ScrubItem(output);
                    }
                    s += _form.TableData(output, "");
                    counter++;
                }

                s += "</tr>";
            }
            s += "</table>";
            s += _summary.PermissionSummary();

            s += "</div>";
            return s;
        }
        public string Vb365ProtStat()
        {
            string s = "<div class=\"protstat\" id=\"protstat\">";
            s += _form.header2("Unprotected Users");
            //s += CollapsibleButton("Show Protection Statistics");
            //s += "<table border=\"1\" style=\"display: none;\"><tr>";
            s += "<table border=\"1\"><tr>";
            //s += _form.TableHeader("User", "User");
            //s += _form.TableHeader("E-mail", "E-mail");
            //s += _form.TableHeader("Organization", "Organization");
            //s += _form.TableHeader("Protection Status", "Protection Status");
            //s += _form.TableHeader("Last Backup Date", "Last Backup Date");

            //s += "</tr>";

            s += "<tr>";
            s += _form.TableHeader("Total Users", "");
            s += _form.TableHeader("Protected Users", "");
            s += _form.TableHeader("Unprotected Users", "");
            s += _form.TableHeader("Stale Backups", "");
            s += "</tr>";
            double protectedUsers = 0;
            double notProtectedUsers = 0;
            double stale = 0;
            var global = _csv.GetDynVboProtStat().ToList();
            var lic = _csv.GetDynamicVboGlobal().ToList();
            //foreach (var li in lic)
            //{
            //    string s2 = li.licensesused;
            //    double.TryParse(s2, out protectedUsers);
            //}
            //int.TryParse(p, out int protectedUsers);
            foreach (var gl in global)
            {
                if (gl.hasbackup == "True" && gl.isstale == "False")
                    protectedUsers++;
                if (gl.hasbackup == "False")
                    notProtectedUsers++;
                if (gl.isstale == "True")
                    stale++;
            }
            // TODO from ProtectionStatus -> (SUM of HasBackup = False) / total rows - 1 = percentage protected
            // (SUM of HasBackup = False) is unprotected users

            double percent = notProtectedUsers / (notProtectedUsers + protectedUsers) * 100;
            double targetPercent = 20;
            int shade = 0;
            if (percent > targetPercent)
            {
                shade = 1;
            }

            s += "<tr>";
            s += _form.TableData((protectedUsers + notProtectedUsers).ToString(), "");
            s += _form.TableData(protectedUsers.ToString(), "");
            s += _form.TableData(notProtectedUsers.ToString(), "", shade);
            s += _form.TableData(stale.ToString(), "");
            s += "</tr>";




            s += "</table>";

            s += _summary.ProtStatSummary();

            s += "</div>";
            return s;
        }
        public string Jobs()
        {
            string s = "<div class=\"jobs\" id=\"jobs\">";
            s += _form.header2("Jobs");
            //s += CollapsibleButton("Show Protection Statistics");
            //s += "<table border=\"1\" style=\"display: none;\"><tr>";
            s += "<table border=\"1\"><tr>";
            s += _form.TableHeader("Organization", Vb365ResourceHandler.jobsTTOrganization );
            s += _form.TableHeader("Name", Vb365ResourceHandler.jobsTTName);
            s += _form.TableHeader("Description", Vb365ResourceHandler.jobsTTDescription);
            s += _form.TableHeader("Job Type", Vb365ResourceHandler.jobsTTJobType );
            s += _form.TableHeader("Scope Type", Vb365ResourceHandler.jobsTTScopeType);
            s += _form.TableHeader("Processing Options", "");
            s += _form.TableHeader("Selected Items", Vb365ResourceHandler.jobsTTSelectedItems);
            s += _form.TableHeader("Excluded Items", Vb365ResourceHandler.jobsTTExcludedItems );
            s += _form.TableHeader("Repository", Vb365ResourceHandler.jobsTTRepository);
            s += _form.TableHeader("Bound Proxy", Vb365ResourceHandler.jobsTTBoundProxy);
            s += _form.TableHeader("Enabled?","");
            s += _form.TableHeader("Schedule", "");
            s += _form.TableHeader("Related Job", Vb365ResourceHandler.jobsTTRelatedJob);

            s += "</tr>";

            var global = _csv.GetDynamicVboJobs().ToList();
            

            foreach (var gl in global)
            {
                var org = "";
                var name = "";
                var desc = "";
                var jobType = "";
                var scopeType = "";
                var procOpt = "";
                var selItems = "";
                var exclItem = "";
                var repo = "";
                var boundProxy = "";
                var enabled = "";
                var schedul = "";
                var relJob = "";

                s += "<tr>";

                int counter = 0;
                foreach (var g in gl)
                {
                    switch (g.Key)
                    {
                        case "boundproxy":
                            boundProxy = g.Value;
                            break;
                        case "organization":
                            org = g.Value;
                            break;
                        case "name":
                            name = g.Value;
                            break;
                        case "description":
                            desc = g.Value;
                            break;
                        case "jobtype":
                            jobType = g.Value;
                            break;
                        case "scopetype":
                            scopeType = g.Value;
                            break;
                        case "procOpt":
                            procOpt = g.Value;
                            break;
                        case "selecteditems":
                            selItems = g.Value;
                            break;
                        case "excludeditems":
                            exclItem = g.Value;
                            break;
                        case "repo":
                            repo = g.Value;
                            break;
                        case "enabled":
                            enabled = g.Value;
                            break;
                        case "schedule":
                            schedul = g.Value;
                            break;
                        case "relatedjob":
                            relJob = g.Value;
                            break;
                        default:
                            break;



                    }
                    string output = g.Value;
                    if (VhcGui._scrub)
                    {
                        org = _scrubber.ScrubItem(org);
                        name = _scrubber.ScrubItem(name);
                        desc = _scrubber.ScrubItem(desc);
                        repo = _scrubber.ScrubItem(repo);
                        boundProxy = _scrubber.ScrubItem(boundProxy);
                    }
                }
                s += _form.TableData(org, "");
                s += _form.TableData(name, "");
                s += _form.TableData(desc, "");
                s += _form.TableData(jobType, "");
                s += _form.TableData(scopeType, "");
                s += _form.TableData(procOpt, "");
                s += _form.TableData(selItems, "");
                s += _form.TableData(exclItem, "");
                s += _form.TableData(repo, "");
                s += _form.TableData(boundProxy, "");
                s += _form.TableData(enabled, "");
                s += _form.TableData(schedul, "");
                s += _form.TableData(relJob, "");

                s += "</tr>";
            }
            //s += "<tr>";
            //s += _form.TableData(counter.ToString(), "");
            //s += "</tr>";



            s += "</table>";

            s += _summary.ProtStatSummary();

            s += "</div>";
            return s;
        }
        public string MakeVb365NavTable()
        {
            return _form.FormNavRows(ResourceHandler.v365NavTitle0, "global", ResourceHandler.v365NavValue1) +
                _form.FormNavRows(ResourceHandler.v365NavTitle1, "protstat", ResourceHandler.v365NavValue1) +
                _form.FormNavRows(ResourceHandler.v365NavTitle2, "controller", ResourceHandler.v365NavValue2) +
                _form.FormNavRows(ResourceHandler.v365NavTitle3, "controllerdrives", ResourceHandler.v365NavValue3) +
                _form.FormNavRows(ResourceHandler.v365NavTitle4, "proxies", ResourceHandler.v365NavValue4) +
                _form.FormNavRows(ResourceHandler.v365NavTitle5, "repos", ResourceHandler.v365NavValue5) +
                _form.FormNavRows(ResourceHandler.v365NavTitle6, "objrepo", ResourceHandler.v365NavValue6) +
                _form.FormNavRows(ResourceHandler.v365NavTitle7, "sec", ResourceHandler.v365NavValue7) +
                _form.FormNavRows(ResourceHandler.v365NavTitle8, "rbac", ResourceHandler.v365NavValue8) +
                //_form.FormNavRows(ResourceHandler.v365NavTitle9, "perms", ResourceHandler.v365NavValue9) +
                _form.FormNavRows(ResourceHandler.v365NavTitle10, "orgs", ResourceHandler.v365NavValue10) +
                _form.FormNavRows(ResourceHandler.v365NavTitle11, "jobs", ResourceHandler.v365NavValue11) +
                _form.FormNavRows(ResourceHandler.v365NavTitle12, "jobstats", ResourceHandler.v365NavValue12) +
                _form.FormNavRows(ResourceHandler.v365NavTitle13, "jobsessions", ResourceHandler.v365NavValue13);
        }

    }
}
