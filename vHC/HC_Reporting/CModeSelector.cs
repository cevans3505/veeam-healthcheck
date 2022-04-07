﻿using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using VeeamHealthCheck.Html;

namespace VeeamHealthCheck
{
    internal class CModeSelector
    {
        private readonly string _path;
        private readonly bool _scrub;
        private readonly bool _openHtml;
        public CModeSelector(string path, bool scrub, bool openHtml)
        {
            _path = path;
            _scrub = scrub;
            _openHtml = openHtml;
        }
        public void Run()
        {
            FileChecker();
        }
        private void FileChecker()
        {
            if(Directory.Exists(CVariables.vb365dir))
                StartM365Report();
            if(Directory.Exists(CVariables.vbrDir))
                StartVbrReportImport();
        }
        private void StartVbrReport()
        {

        }
        private void StartVbrReportImport()
        {
            CCsvToXml c = new("vbr", _scrub, false, _openHtml, true);

            //choose VBO or VBR
            c.ConvertToXml();
        }
        private void StartM365Report()
        {
            //CCsvToXml m = new CCsvToXml("m365", _scrub, false, _openHtml, true);
            CM365Converter converter = new CM365Converter();
        }
    }
}