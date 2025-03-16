/* clang-format off */

DocMax(Fs);
WinMax(Fs);

#include "Modules/Log";
#include "Modules/Db";
#include "Modules/Http";
#include "Modules/Api";

#include "Api/V1/Accounts";
#include "Api/V1/Announcements";
#include "Api/V1/Apps";
#include "Api/V1/Blocks";
#include "Api/V1/Bookmarks";
#include "Api/V1/Conversations";
#include "Api/V1/CustomEmojis";
#include "Api/V1/Favourites";
#include "Api/V1/Filters";
#include "Api/V1/FollowRequests";
#include "Api/V1/FollowedTags";
#include "Api/V1/Markers";
#include "Api/V1/Media";
#include "Api/V1/Notifications";
#include "Api/V1/Polls";
#include "Api/V1/Statuses";
#include "Api/V1/Timelines";

#include "Api/V2/Filters";
#include "Api/V2/Instance";
#include "Api/V2/Media";
#include "Api/V2/Search";
#include "Api/V2/Suggestions";

#include "Modules/ActivityPub";
#include "Modules/Meta";
#include "Modules/NodeInfo";
#include "Modules/OAuth";
#include "Modules/Web";
#include "Modules/Webfinger";

#include "Http/Server";
#include "Http/LocalServer";
#include "Http/AdminServer";

@slon_log(0, "slon is up and running");
@slon_log(0, "instance on port 80, fs on port 8000, admin on port 9000");

WinToTop(adam_task);
