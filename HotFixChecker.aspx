<%@ Page Language="C#" AutoEventWireup="true" Debug="true" %>

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" >
<%@ Import Namespace="System" %>
<%@ Import Namespace="System.Collections" %>
<%@ Import Namespace="System.Collections.Generic" %>
<%@ Import Namespace="System.Configuration" %>
<%@ Import Namespace="System.Data" %>
<%@ Import Namespace="System.Web" %>
<%@ Import Namespace="System.Web.Security" %>
<%@ Import Namespace="System.Web.UI" %>
<%@ Import Namespace="System.Web.UI.HtmlControls" %>
<%@ Import Namespace="System.Web.UI.WebControls" %>
<%@ Import Namespace="System.IO" %>
<%@ Import Namespace="Sitecore.Configuration" %>
<%@ Import Namespace="System.ServiceModel.Syndication" %>
<%@ Import Namespace="System.Xml" %>
<%@ Import Namespace="HtmlAgilityPack" %>
<%@ Import Namespace="Newtonsoft.Json" %>


<%--Author : Kiran Patil
Version : 1.0.0.0--%>

<script language="C#" runat="server">   

    private void Page_Load(object sender, EventArgs e)
    {
        try
        {
            if (!IsPostBack)
            {
                var hotFixData = GetHotFixData();
                ShowHotFixList(hotFixData);
            }
        }
        catch (Exception ex)
        {
            litMessage.Text =
                "Something went wrong while loading hotfix checker : " + ex.Message
                + ". Please check log file for more details.";
            Sitecore.Diagnostics.Log.Error(litMessage.Text
                , ex, this);
        }
    }

    private HotFixCheckerInfo GetHotFixData()
    {
        HotFixCheckerInfo hotFixCheckerInfo = new HotFixCheckerInfo();

        // Identify Sitecore Version
        //  /sitecore/shell/sitecore.version.xml
        hotFixCheckerInfo.SitecoreVersion = ReadXMLData("SITECOREVERSION"); //"Sitecore.NET 9.1.1 (rev. 002459)";
                                                                            // Load local assemblies
                                                                            // Load local files
                                                                            //  /sitecore/shell/patches
                                                                            //  /sitecore/shell/hotfixes
        hotFixCheckerInfo.InstalledHotfixes = new List<string>();
        var hotFixFromAssemblies = GetInstalledHotFixes(hotFixCheckerInfo.InstalledHotfixes);
        hotFixCheckerInfo.InstalledHotfixes.Add("Sitecore.Support.82262");
        //hotFixCheckerInfo.InstalledHotfixes.Add("Sitecore.Support.96688");


        // Identify Sitecore Version from Kernel assembly
        // Recommended list
        hotFixCheckerInfo.RecommendedHotfixes = new List<HotFixInfo>();
        bool compareWithMyCurrentVersionOnly = true; //TODO: Show all?
        LoadRecommendedHotfixFeed(hotFixCheckerInfo, compareWithMyCurrentVersionOnly);
        return hotFixCheckerInfo;
    }

    private List<string> GetInstalledHotFixes(List<string> installedHotfixes)
    {
        // Assemblies
        string[] assemblyFilters = new string[] { "Sitecore.Support" };
        var assemblyNames = new HashSet<string>(assemblyFilters.Where(filter => !filter.Contains('*')));
        foreach (var assemblyToCheck in AppDomain.CurrentDomain.GetAssemblies())
        {
            var nameToMatch = assemblyToCheck.GetName().Name;
            if (assemblyNames.Contains(nameToMatch) && !installedHotfixes.Contains(nameToMatch))
                installedHotfixes.Add(nameToMatch);
        }
        // Patches and Hotfixes - Not required as it in zip file

        // Check App-Config - This is double check logic
        var appConfigFolderPath = Server.MapPath("~/App_Config");
        var allFileSystemEntries =
            Directory.GetFileSystemEntries(appConfigFolderPath, "Sitecore.Support.*", SearchOption.AllDirectories);
        foreach (var configFile in allFileSystemEntries)
        {
            if(!installedHotfixes.Contains(configFile))
            {
                installedHotfixes.Add(configFile);
            }
        }

        return installedHotfixes;
    }
    private string ReadXMLData(string infoToGet)
    {
        string xmlInfoToReturn = string.Empty;
        XmlDocument xmlDoc = new XmlDocument();
        switch (infoToGet)
        {

            case "SITECOREVERSION":
                string versionXMLPath = Server.MapPath("~/sitecore/shell/sitecore.version.xml");
                xmlDoc.Load(versionXMLPath);
                if (xmlDoc != null)
                {
                    var versionNode = xmlDoc.SelectSingleNode("/information/version");
                    if (versionNode != null && versionNode.HasChildNodes)
                    {
                        StringBuilder versionString = new StringBuilder();
                        versionString.AppendFormat("{0}.", versionNode.SelectSingleNode("major").InnerText);
                        versionString.AppendFormat("{0}.", versionNode.SelectSingleNode("minor").InnerText);
                        versionString.AppendFormat("{0}.", versionNode.SelectSingleNode("build").InnerText);
                        versionString.AppendFormat("{0}", versionNode.SelectSingleNode("revision").InnerText);
                        xmlInfoToReturn = versionString.ToString();
                    }
                }
                break;
            case "":
                break;
            default:
                xmlInfoToReturn = "NA";
                break;
        }
        return xmlInfoToReturn;
    }

    private void LoadRecommendedHotfixFeed(HotFixCheckerInfo hotFixCheckerInfo, bool compareWithMyCurrentVersionOnly)
    {

        string json = new System.Net.WebClient().DownloadString("https://dng91.sc/versionCrawlHotfix-new.json");
        var hotFixData = JsonConvert.DeserializeObject<List<RecommendedHotFix>>(json);
        hotFixCheckerInfo.RecommendedHotfixes = new List<HotFixInfo>();

        foreach (var hotFix in hotFixData)
        {
            hotFixCheckerInfo.RecommendedHotfixes.Add(new HotFixInfo()
            {
                Title = hotFix.html_url.Replace("https://github.com/SitecoreSupport/", string.Empty),
                Description = hotFix.description,
                Versions = hotFix.version,
                Link = hotFix.html_url,
                PublishDate = hotFix.lastupdatedate.ToUniversalTime().ToString(),
            });
        }
        if (compareWithMyCurrentVersionOnly)
        {
            // Filter version
            hotFixCheckerInfo.RecommendedHotfixes = hotFixCheckerInfo.
                RecommendedHotfixes.Where(x => x.Versions.Contains(hotFixCheckerInfo.SimpleSitecoreVersion)).ToList();
        }

    }
    /// <summary>
    /// This function will be used to
    /// Reset Cache List
    /// </summary>
    private void ShowHotFixList(HotFixCheckerInfo hotFixCheckerInfo)
    {

        litMessage.Text = "Your Sitecore version is : " + hotFixCheckerInfo.SitecoreVersion + " ("
           + hotFixCheckerInfo.SimpleSitecoreVersion + ")";

        HtmlTable table = tblHotFixData;
        Sitecore.Web.HtmlUtil.AddRow(table, new string[] { "Title", "Description", "Publish Date","State",
            "Link", "Recommendation","Versions"});
        table.Rows[0].Style.Add(HtmlTextWriterStyle.BackgroundColor, "#DDEAF9");
        table.Rows[0].Style.Add(HtmlTextWriterStyle.Color, "black");
        table.Rows[0].Style.Add(HtmlTextWriterStyle.BorderCollapse, "collapse");
        table.Rows[0].Style.Add("border", "1px solid red");
        table.Rows[0].Style.Add(HtmlTextWriterStyle.TextAlign, "center");
        table.Rows[0].Style.Add(HtmlTextWriterStyle.FontWeight, "bold");

        // Loop through all recommendations
        foreach (var recommendedHotFix in hotFixCheckerInfo.RecommendedHotfixes)
        {
            string backGroundColor = "white";

            if (!hotFixCheckerInfo.InstalledHotfixes.Contains(recommendedHotFix.Title))
            {
                recommendedHotFix.State = "Pending";
                recommendedHotFix.Recommendation = @"This hotfix is not yet installed.";
                backGroundColor = "red";
            }
            else
            {
                recommendedHotFix.State = "Installed";
                recommendedHotFix.Recommendation = @"This hotfix is already installed.";
                backGroundColor = "lightgreen";
            }

            // Add Row data
            HtmlTableRow row = Sitecore.Web.HtmlUtil.AddRow(table,
                new string[] {
                    recommendedHotFix.Title,
                    recommendedHotFix.Description,
                    recommendedHotFix.PublishDate,
                    recommendedHotFix.State,
                    string.Format("<a href='{0}' target='_blank'>{1}</a>",recommendedHotFix.Link,recommendedHotFix.Title),
                    recommendedHotFix.Recommendation,
                    string.Join(",",recommendedHotFix.Versions)
        });
            row.BgColor = backGroundColor;
        }
    }

    public class HotFixCheckerInfo
    {
        public string SitecoreVersion { get; set; }
        public string SimpleSitecoreVersion
        {
            get
            {
                // TODO : Update
                return "8.0.6.0";
                //var splittedSitecoreVersion = 
                //    SitecoreVersion.Split('.');

                //switch (splittedSitecoreVersion.Last())
                //{
                //    case "":
                //    default:
                //        return "NA";
                //        break;
                //}
            }
        }

        public List<string> InstalledHotfixes { get; set; }

        public List<HotFixInfo> RecommendedHotfixes { get; set; }

    }

    public class HotFixInfo
    {
        public string Title { get; set; }
        public string Description { get; set; }
        public string PublishDate { get; set; }
        public string Link { get; set; }
        public List<string> Versions { get; set; }
        public string State { get; set; }
        public string Recommendation { get; set; }
    }

    public class RecommendedHotFix
    {
        public string tags_url { get; set; }
        public string html_url { get; set; }
        public string description { get; set; }
        public DateTime createddate { get; set; }
        public DateTime lastupdatedate { get; set; }
        public List<string> version { get; set; }

    }

</script>

<html>
<head>
    <title>Hotfix Checker</title>
    <meta content="Microsoft Visual Studio .NET 7.1" name="GENERATOR">
    <meta content="C#" name="CODE_LANGUAGE">
    <meta content="JavaScript" name="vs_defaultClientScript">
    <meta content="http://schemas.microsoft.com/intellisense/ie5" name="vs_targetSchema">
    <style type="text/css">
        body {
            font-size: medium;
            color: #000;
            font-family: "Lucida Grande", "Calibri", helvetica, sans-serif;
            scrollbar-3dlight-color: #DDEAF9;
            scrollbar-arrow-color: #1C3C82;
            scrollbar-base-color: #DDEAF9;
            scrollbar-darkshadow-color: #DDEAF9;
            scrollbar-face-color: #DDEAF9;
            scrollbar-highlight-color: black;
            scrollbar-shadow-color: black;
            font-size: small;
            background: #F7F7F7 none repeat scroll 0 0;
        }

        .button {
            -moz-border-radius-bottomleft: 7px;
            -moz-border-radius-bottomright: 7px;
            -moz-border-radius-topleft: 7px;
            -moz-border-radius-topright: 7px;
            background-color: #DDEAF9;
            border: 1px solid #AAB7C6;
            display: inline-block;
            margin: 0 5px 10px 0;
            padding: 3px;
            border-color: darkgreen;
        }

        .data {
            border-collapse: collapse;
            margin: 10px 0 0;
            width: 100%;
            border-color: darkgreen;
        }

            .data td {
                border: 1px solid darkgreen;
                padding: 5px;
            }

        #content {
            -moz-border-radius-bottomleft: 7px;
            -moz-border-radius-bottomright: 7px;
            -moz-border-radius-topleft: 7px;
            -moz-border-radius-topright: 7px;
            background-color: #FFFFFF;
            border: 2px solid #FFFFFF;
            color: black;
            line-height: 1.5em;
        }

        #shortnotice {
            background-color: #FFDDDD;
            border: 1px solid #FFDDDD;
            font-weight: bold;
            width: 100%;
        }
    </style>
</head>
<body>
    <form id="Form1" method="post" runat="server">
        <table id="tableData" cellspacing="1" cellpadding="1" border="1" class="data">
            <tr>
                <td style="height: 36px" colspan="3" align="center">
                    <div id="shortnotice">
                        <asp:Literal ID="litMessage" runat="server" />
                    </div>
                </td>
            </tr>
            <%-- <tr>
                <td align="right">
                    <asp:Button ID="btnrefresh" runat="server" Text="Refresh" CssClass="button"></asp:Button>
                    <asp:Button ID="btnDownloadCSV" runat="server" Text="Export to CSV" Visible="true"
                        CssClass="button" Enabled="false"></asp:Button>
                </td>
            </tr>--%>
            <tr>
                <td>
                    <div id="content">
                        <table runat="server" id="tblHotFixData" border="1" width="100%" cellpadding="4"
                            class="data">
                        </table>
                    </div>
                </td>
            </tr>
            <tr>
                <td colspan="3">
                    <div id="shortnotice">
                        Before installing any Sitecore patch. Please go through following links:
                        <ul>
                            <li><a href="https://www.sitecorehotfixversionselector.com/" target="_blank">https://www.sitecorehotfixversionselector.com/</a>

                            </li>
                            <li><a href="https://github.com/SitecoreSupport/Important-Information" target="_blank">https://github.com/SitecoreSupport/Important-Information</a>

                            </li>
                        </ul>
                    </div>
                </td>
            </tr>
        </table>
    </form>
</body>
</html>
