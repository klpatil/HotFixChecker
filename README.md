# Hotfix Checker (HFC)
---
HFC allows you to compare installed hotfixes with should be installed hotfixes.

![Hotfix Checker (HFC)](https://sitecorebasics.files.wordpress.com/2019/09/hfcv1.0.gif "Hotfix Checker (HFC)")


## Main Features

1. HFC lists all installed Sitecore recommended hotfixes form your current application.
2. If you have XP Scaled environment then you need to run this tool on each role.
3. It also identifies your Sitecore version.
4. It fetches latest list of recommended hotfixes provided by Sitecore from their Github Repo : https://github.com/SitecoreSupport using  https://www.sitecorehotfixversionselector.com/ (Thanks to https://twitter.com/bramstoopcom and https://twitter.com/MariaBorhem for simplifying this check)
5. By default it does comparison with your current version and applies filter on Sitecore's recommended hotfix list for your version. But Sitecore's github repository version mapping is still in early stage. So, you might find some errors there. In that case, you might want to do manual comparison. To make that process easy for your eyes - HFC has option "Compare All" using that you can list all Sitecore hotfixes and do manual comparison. Also, don't forget you have Search as well, which works on all columns!

## Caveats
1. Sitecore version tagging is not accurate for git repository. So, please double check before applying any patch.
2. Please don't apply any patch, without consulting with Sitecore support team.
3. Intentionally we have not applied Security on this page. So, please delete it once you are done with your check.

## How to Download and Install?

1. If you would like to do it manually you can download file (HFC.aspx) from here
2. Copy it under your #WEBROOT#\\#YOURFOLDER# folder.
3. Access your page using https://#WEBROOT#/#YOURFOLDER#/hfc.aspx
4. That's it! Enjoy! :-)

>Found any bug? Got suggestion/feedback/comment, Share it here!
