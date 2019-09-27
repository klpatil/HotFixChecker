<%@ Page Language="C#" AutoEventWireup="true" Debug="true" %>

<!DOCTYPE html>
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
<%@ Import Namespace="System.Linq" %>
<%@ Import Namespace="HtmlAgilityPack" %>
<%@ Import Namespace="Newtonsoft.Json" %>

<%--Author : Kiran Patil
Version : 1.0.--%>

<script language="C#" runat="server">   

    HotFixCheckerInfo hotFixData = null;
    private void Page_Load(object sender, EventArgs e)
    {
        try
        {
            if (!IsPostBack)
            {
                hotFixData = GetHotFixData();
                ShowHotFixList(hotFixData);
            }
        }
        catch (Exception ex)
        {
            lblMessage.Text =
                "Something went wrong while loading hotfix checker : " + ex.Message
                + ". Please check log file for more details.";
            lblMessage.CssClass = "text-danger";
            Sitecore.Diagnostics.Log.Error(lblMessage.Text
                , ex, this);
        }
    }

    private HotFixCheckerInfo GetHotFixData()
    {
        HotFixCheckerInfo hotFixCheckerInfo = new HotFixCheckerInfo();

        // Identify Sitecore Version
        //  /sitecore/shell/sitecore.version.xml
        hotFixCheckerInfo.SitecoreVersion = ReadXMLData("SITECOREVERSION");
        hotFixCheckerInfo.InstalledHotfixes = new List<string>();
        var hotFixFromAssemblies = GetInstalledHotFixes(hotFixCheckerInfo.InstalledHotfixes);

        // Identify Sitecore Version from Kernel assembly
        // Recommended list
        hotFixCheckerInfo.RecommendedHotfixes = new List<HotFixInfo>();
        bool compareWithMyCurrentVersionOnly = true;
        if (Request.QueryString["showall"] == "1")
            compareWithMyCurrentVersionOnly = false;
        LoadRecommendedHotfixFeed(hotFixCheckerInfo, compareWithMyCurrentVersionOnly);
        return hotFixCheckerInfo;
    }


    private List<string> GetInstalledHotFixes(List<string> installedHotfixes)
    {
        // Assemblies
        string assemblyFilter = "Sitecore.Support";
        foreach (var assemblyToCheck in AppDomain.CurrentDomain.GetAssemblies())
        {
            var nameToMatch = assemblyToCheck.GetName().Name;
            if (nameToMatch.StartsWith(assemblyFilter, StringComparison.InvariantCultureIgnoreCase)
                && !installedHotfixes.Contains(nameToMatch))
                installedHotfixes.Add(nameToMatch);
        }
        // Check App-Config - This is double check logic
        var appConfigFolderPath = Server.MapPath("~/App_Config");
        var allFileSystemEntries =
            Directory.GetFileSystemEntries(appConfigFolderPath, "Sitecore.Support.*", SearchOption.AllDirectories);
        foreach (var configFile in allFileSystemEntries)
        {
            var fileName = Path.GetFileName(configFile).
                Replace(".config", string.Empty);
            if (!installedHotfixes.Contains(fileName))
            {
                installedHotfixes.Add(fileName);
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
            default:
                xmlInfoToReturn = "NA";
                break;
        }
        return xmlInfoToReturn;
    }

    private void LoadRecommendedHotfixFeed(HotFixCheckerInfo hotFixCheckerInfo, bool compareWithMyCurrentVersionOnly)
    {

        string json =
            new System.Net.WebClient()
            .DownloadString("https://shvsstorage.blob.core.windows.net/sitecorehotfixpublicjson/sitecorehotfixversionselector.json");
        var hotFixData = JsonConvert.DeserializeObject<List<RecommendedHotFix>>(json);
        hotFixCheckerInfo.RecommendedHotfixes = new List<HotFixInfo>();

        foreach (var hotFix in hotFixData)
        {
            if (compareWithMyCurrentVersionOnly)
            {
                // Compare and if version match then only go to next line
                // or next line
                foreach (var version in hotFix.version)
                {
                    if (version != null &&
                        version.StartsWith(hotFixCheckerInfo.SimpleSitecoreVersion, StringComparison.InvariantCultureIgnoreCase))
                    {
                        hotFixCheckerInfo.RecommendedHotfixes.Add(new HotFixInfo()
                        {
                            Title = hotFix.html_url.Replace("https://github.com/SitecoreSupport/", string.Empty),
                            Description = hotFix.description,
                            Versions = hotFix.version,
                            Link = hotFix.html_url,
                            PublishDate = hotFix.lastupdatedate.ToUniversalTime().ToString(),
                        });
                        break; // one match is also fine
                    }
                }
            }
            else
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

        }
    }
    /// <summary>
    /// This function will be used to
    /// Reset Cache List
    /// </summary>
    private void ShowHotFixList(HotFixCheckerInfo hotFixCheckerInfo)
    {

        //<span class="label label-success">Success</span>

        lblMessage.Text = string.Format(@"Your Sitecore version is : <span class='label label-success'>{0} ({1})</span>. 
                                    Default results are compared with your current version. 
                                    But Sitecore hotfix repository tagging is not yet accurate. So, in case you would like to compare 
                                    results with all hotfix. You can use <strong>Compare All</strong> 
                                    option or click on <strong>Just My</strong> to compare with your current version only.",
                                    hotFixCheckerInfo.SitecoreVersion, hotFixCheckerInfo.SimpleSitecoreVersion);
        lblMessage.CssClass = "text-success";

        var table = tblHotFixData;

        List<HotFixInfo> finalList = new List<HotFixInfo>();
        int installedSortOrder = 1;
        int notInstalledSortOrder = hotFixCheckerInfo.InstalledHotfixes.Count + 1;
        // Loop through all recommendations
        foreach (var recommendedHotFix in hotFixCheckerInfo.RecommendedHotfixes)
        {
            if (!hotFixCheckerInfo.InstalledHotfixes.Contains(recommendedHotFix.Title))
            {
                recommendedHotFix.State = "Pending";
                recommendedHotFix.Recommendation = @"This hotfix is not yet installed.";
                recommendedHotFix.SortOrder = notInstalledSortOrder++;
                if (!finalList.Exists(x => x.Title == recommendedHotFix.Title))
                    finalList.Add(recommendedHotFix);
            }
            else
            {
                recommendedHotFix.State = "Installed";
                recommendedHotFix.Recommendation = @"This hotfix is already installed.";
                recommendedHotFix.SortOrder = installedSortOrder++;
                if (!finalList.Exists(x => x.Title == recommendedHotFix.Title))
                    finalList.Add(recommendedHotFix);
            }
        }

        // Sort all installed first
        finalList.Sort((a, b) => (a.SortOrder.CompareTo(b.SortOrder)));

        // Render           
        foreach (var aFinalHotFix in finalList)
        {
            TableRow tableRow = new TableRow();
            tableRow.CssClass = (aFinalHotFix.State == "Installed") ? "success" : "danger";
            tableRow.TableSection = TableRowSection.TableBody;


            TableCell tcell = new TableCell();
            tcell.Attributes.Add("data-toggle", "tooltip");
            tcell.Attributes.Add("title", aFinalHotFix.Recommendation);
            tcell.Text = aFinalHotFix.Title;

            tableRow.Cells.Add(tcell);
            tableRow.Cells.Add(new TableCell() { Text = aFinalHotFix.Description });
            tableRow.Cells.Add(new TableCell() { Text = aFinalHotFix.PublishDate });
            tableRow.Cells.Add(new TableCell() { Text = aFinalHotFix.State });
            tableRow.Cells.Add(new TableCell()
            {
                Text = string.Format("<a href='{0}' target='_blank'>{1}</a>", aFinalHotFix.Link, aFinalHotFix.Title)
            }
            );
            tableRow.Cells.Add(new TableCell() { Text = string.Join("<br/>", aFinalHotFix.Versions) });
            table.Rows.Add(tableRow);

        }

        tblHotFixData.Visible = true;

    }



    public class HotFixCheckerInfo
    {
        static Dictionary<string, string> sitecoreVersionMapping = new Dictionary<string, string>();

        static HotFixCheckerInfo()
        {
            // SC6.5
            sitecoreVersionMapping.Add("6.5.0.110602", "6.5.0");
            sitecoreVersionMapping.Add("6.5.0.110818", "6.5.1");
            sitecoreVersionMapping.Add("6.5.0.111123", "6.5.2");
            sitecoreVersionMapping.Add("6.5.0.111230", "6.5.3");
            sitecoreVersionMapping.Add("6.5.0.120427", "6.5.4");
            sitecoreVersionMapping.Add("6.5.0.120706", "6.5.5");
            sitecoreVersionMapping.Add("6.5.0.121009", "6.5.6");

            // SC6.6
            sitecoreVersionMapping.Add("6.6.0.120918", "6.6.0");
            sitecoreVersionMapping.Add("6.6.0.121015", "6.6.1");
            sitecoreVersionMapping.Add("6.6.0.121203", "6.6.2");
            sitecoreVersionMapping.Add("6.6.0.130111", "6.6.3");
            sitecoreVersionMapping.Add("6.6.0.130214", "6.6.4");
            sitecoreVersionMapping.Add("6.6.0.130404", "6.6.5");
            sitecoreVersionMapping.Add("6.6.0.130529", "6.6.6");
            sitecoreVersionMapping.Add("6.6.0.131211", "6.6.7");
            sitecoreVersionMapping.Add("6.6.0.140410", "6.6.8");

            // SC7.0
            sitecoreVersionMapping.Add("7.0.0.130424", "7.0.0");
            sitecoreVersionMapping.Add("7.0.0.130810", "7.0.1");
            sitecoreVersionMapping.Add("7.0.0.130918", "7.0.2");
            sitecoreVersionMapping.Add("7.0.0.131127", "7.0.3");
            sitecoreVersionMapping.Add("7.0.0.140120", "7.0.4");
            sitecoreVersionMapping.Add("7.0.0.140408", "7.0.5");

            // SC7.1
            sitecoreVersionMapping.Add("7.1.0.130926", "7.1.0");
            sitecoreVersionMapping.Add("7.1.0.140130", "7.1.1");
            sitecoreVersionMapping.Add("7.1.0.140324", "7.1.2");
            sitecoreVersionMapping.Add("7.1.0.140905", "7.1.3");

            // SC7.2
            sitecoreVersionMapping.Add("7.2.0.140228", "7.2.0");
            sitecoreVersionMapping.Add("7.2.0.140314", "7.2.1");
            sitecoreVersionMapping.Add("7.2.0.140526", "7.2.2");
            sitecoreVersionMapping.Add("7.2.0.141226", "7.2.3");
            sitecoreVersionMapping.Add("7.2.0.150408", "7.2.4");
            sitecoreVersionMapping.Add("7.2.0.151021", "7.2.5");
            sitecoreVersionMapping.Add("7.2.0.160123", "7.2.6");

            // SC7.5
            sitecoreVersionMapping.Add("7.5.0.141003", "7.5.0");
            sitecoreVersionMapping.Add("7.5.0.150130", "7.5.1");
            sitecoreVersionMapping.Add("7.5.0.150212", "7.5.2");

            // SC8.0
            sitecoreVersionMapping.Add("8.0.0.141212", "8.0.0");
            sitecoreVersionMapping.Add("8.0.0.150121", "8.0.1");
            sitecoreVersionMapping.Add("8.0.0.150223", "8.0.2");
            sitecoreVersionMapping.Add("8.0.0.150427", "8.0.3");
            sitecoreVersionMapping.Add("8.0.0.150621", "8.0.4");
            sitecoreVersionMapping.Add("8.0.0.150812", "8.0.5");
            sitecoreVersionMapping.Add("8.0.0.151127", "8.0.6");
            sitecoreVersionMapping.Add("8.0.0.160115", "8.0.7");

            // SC8.1
            sitecoreVersionMapping.Add("8.1.0.151003", "8.1.0");
            sitecoreVersionMapping.Add("8.1.0.151207", "8.1.1");
            sitecoreVersionMapping.Add("8.1.0.160302", "8.1.2");
            sitecoreVersionMapping.Add("8.1.0.160519", "8.1.3");

            // SC8.2
            sitecoreVersionMapping.Add("8.2.0.160729", "8.2.0");
            sitecoreVersionMapping.Add("8.2.0.161115", "8.2.1");
            sitecoreVersionMapping.Add("8.2.0.161221", "8.2.2");
            sitecoreVersionMapping.Add("8.2.0.170407", "8.2.3");
            sitecoreVersionMapping.Add("8.2.0.170614", "8.2.4");
            sitecoreVersionMapping.Add("8.2.0.170728", "8.2.5");
            sitecoreVersionMapping.Add("8.2.0.171121", "8.2.6");
            sitecoreVersionMapping.Add("8.2.0.180406", "8.2.7");

            // SC9.0
            sitecoreVersionMapping.Add("9.0.2.171002", "9.0.0");
            sitecoreVersionMapping.Add("9.0.2.171219 ", "9.0.1");
            sitecoreVersionMapping.Add("9.0.2.180604", "9.0.2");

            // 9.1
            sitecoreVersionMapping.Add("9.1.1.001564", "9.1.0");
            sitecoreVersionMapping.Add("9.1.1.002459", "9.1.1");

            // 9.2
            sitecoreVersionMapping.Add("9.2.0.002893", "9.2.0");

        }

        static string GetSitecoreSimpleVersion(string yourSitecoreVersion)
        {
            // https://www.sitecoregabe.com/2018/11/which-version-of-sitecore-is-this-again.html
            // https://sitecore.stackexchange.com/questions/4358/can-you-identify-the-sitecore-version-from-the-sitecore-kernel-dll-version
            
            return (sitecoreVersionMapping.ContainsKey(yourSitecoreVersion)) ? sitecoreVersionMapping[yourSitecoreVersion] : "0";
        }

        public string SitecoreVersion { get; set; }
        public string SimpleSitecoreVersion
        {
            get
            {
                return GetSitecoreSimpleVersion(SitecoreVersion);

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
        public int SortOrder { get; set; }
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

<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <meta charset="utf-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <!-- The above 3 meta tags *must* come first in the head; any other head content must come *after* these tags -->
    <title>Hotfix Checker (HFC) - 1.0</title>
    <!-- Bootstrap -->
    <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/3.4.1/css/bootstrap.min.css" integrity="sha384-HSMxcRTRxnN+Bdg0JdbxYKrThecOKuH5zCYotlSAcp1+c8xmyTe9GYg1l9a69psu" crossorigin="anonymous">

    <link rel="stylesheet" type="text/css" href="https://cdn.datatables.net/1.10.19/css/jquery.dataTables.min.css">

    <!-- HTML5 shim and Respond.js for IE8 support of HTML5 elements and media queries -->
    <!-- WARNING: Respond.js doesn't work if you view the page via file:// -->
    <!--[if lt IE 9]>
      <script src="https://oss.maxcdn.com/html5shiv/3.7.3/html5shiv.min.js"></script>
      <script src="https://oss.maxcdn.com/respond/1.4.2/respond.min.js"></script>
    <![endif]-->

</head>

<body>
    <form id="Form1" method="post" runat="server">

        <div class="container-fluid" role="main">

            <div class="row">
                <div class="page-header">
                    <h1>Hotfix Checker (HFC) <small>Compares installed hotfixes with should be installed hotfixes.</small></h1>
                </div>

                <div class="panel-group" id="accordion" role="tablist" aria-multiselectable="true">
                    <div class="panel panel-default">
                        <div class="panel-heading" role="tab" id="headingOne">
                            <h4 class="panel-title">
                                <a role="button" data-toggle="collapse"
                                    data-parent="#accordion"
                                    href="#collapseOne" aria-expanded="true" aria-controls="collapseOne">Your Sitecore Version (Click here to expand/collapse)
                                </a>
                            </h4>
                        </div>
                        <div id="collapseOne"
                            class="panel-collapse collapse in" role="tabpanel" aria-labelledby="headingOne">
                            <div class="panel-body">
                                <span class="label label-info">Info</span>

                                <asp:Label ID="lblMessage" runat="server" Text=""
                                    Visible="true" />
                                <p>
                                    <a href="?showall=1" class="btn btn-primary btn-xs" role="button">Compare All</a>
                                    &nbsp;
                                <a href="?showall=0" class="btn btn-primary btn-xs" role="button">Just My</a>
                                </p>

                            </div>
                        </div>
                    </div>
                    <div class="panel panel-default">
                        <div class="panel-heading" role="tab" id="headingTwo">
                            <h4 class="panel-title">
                                <a class="collapsed" role="button" data-toggle="collapse"
                                    data-parent="#accordion" href="#collapseTwo" aria-expanded="false"
                                    aria-controls="collapseTwo">Notes :  (Click here to expand/collapse)
                                </a>
                            </h4>
                        </div>
                        <div id="collapseTwo" class="panel-collapse collapse" role="tabpanel" aria-labelledby="headingTwo">
                            <div class="panel-body">
                                Before installing any Sitecore patch. Please go through following links:
                        <ul>
                            <li><a href="https://www.sitecorehotfixversionselector.com/" target="_blank">https://www.sitecorehotfixversionselector.com/</a>

                            </li>
                            <li><a href="https://github.com/SitecoreSupport/Important-Information" target="_blank">https://github.com/SitecoreSupport/Important-Information</a>

                            </li>
                            <li>
                                HFC will check current application only. If you've XP Scaled, then you need to run HFC on each role.
                            </li>
                        </ul>
                            </div>
                        </div>
                    </div>

                </div>

            </div>


            <div class="row">
                <div class="col-md-12">
                    <asp:Table ID="tblHotFixData"
                        CellPadding="0" CellSpacing="0" runat="server" Width="100%"
                        CssClass="table" Visible="false">
                        <asp:TableHeaderRow TableSection="TableHeader">
                            <asp:TableHeaderCell>Title</asp:TableHeaderCell>
                            <asp:TableHeaderCell>Description</asp:TableHeaderCell>
                            <asp:TableHeaderCell>Publish Date</asp:TableHeaderCell>
                            <asp:TableHeaderCell>State</asp:TableHeaderCell>
                            <asp:TableHeaderCell>Link</asp:TableHeaderCell>
                            <asp:TableHeaderCell>Versions</asp:TableHeaderCell>
                        </asp:TableHeaderRow>
                    </asp:Table>
                </div>



            </div>
            <!-- /container -->
        </div>
    </form>
</body>

<!-- jQuery (necessary for Bootstrap's JavaScript plugins) -->
<script src="https://code.jquery.com/jquery-1.12.4.min.js" integrity="sha384-nvAa0+6Qg9clwYCGGPpDQLVpLNn0fRaROjHqs13t4Ggj3Ez50XnGQqc/r8MhnRDZ" crossorigin="anonymous"></script>
<!-- Include all compiled plugins (below), or include individual files as needed -->
<script src="https://stackpath.bootstrapcdn.com/bootstrap/3.4.1/js/bootstrap.min.js" integrity="sha384-aJ21OjlMXNL5UyIl/XNwTMqvzeRMZH2w8c5cRVpzpU8Y5bApTppSuUkhZXN0VxHd" crossorigin="anonymous"></script>
<script type="text/javascript" language="javascript" src="https://cdn.datatables.net/1.10.19/js/jquery.dataTables.min.js"></script>
<script language="javascript" type="text/javascript">
    $(function () {
        $("body").tooltip({
            selector: '[data-toggle="tooltip"]',
            container: 'body'
        });
    })

    $(document).ready(function () {
        $('#tblHotFixData').DataTable({
            "lengthMenu": [[10, 25, 50, 100, 200, -1], [10, 25, 50, 100, 200, "All"]],
            "order": [[3, "asc"]]
        });
    });
</script>
</html>
