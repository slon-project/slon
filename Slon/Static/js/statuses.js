function updateStatusContainers() {
    let els = document.getElementsByClassName('status-container');
    for (var n = 0; n < els.length; n++) {
        let pc = els[n];
        let post_html = ""

        let horizontal_fill_count = ((pc.offsetWidth - 32) / 16);
        let url = pc.getElementsByTagName('url')[0].textContent;
        let marqueeHref = url == "Unnamed Task" ? window.location : url;
        if (url.substring(0,1) == '_') {
            url = url.substring(1);
            marqueeHref = window.location;
        }

        post_html += "<b>\u2554";
        for (var i = 0; i < (horizontal_fill_count / 2) - ((240 / 16) / 2); i++) {
            post_html += "\u2550";
        }

        post_html += "<a href=\"" + marqueeHref + "\"><marquee scrollamount=16>" + url + "...</marquee></a>";
        for (var i = 0; i < (horizontal_fill_count / 2) - ((240 / 16) / 2) - 2; i++) {
            post_html += "\u2550";
        }
        post_html += "[X]\u2557<br></b>";

        let height = Math.ceil(pc.getElementsByClassName('status-content')[0].offsetHeight / 16);
        let desc = "Term";

        for (var y = 0; y < height; y++) {
            let ch = y < 4 ? desc[y] : "\u2551";
            post_html += "<b>" + ch + "<div style=\"display: inline-block; height: 16px; width: " + ((horizontal_fill_count + 1) * 16).toString() + "px\"></div>\u2551</b><br>";
        }

        post_html += "<b>\u255a";
        for (var i = 0; i < (horizontal_fill_count + 1); i++) {
            post_html += "\u2550";
        }
        post_html += "\u255d<br></b>";

        pc.innerHTML += post_html;
        pc.style.display = "inline";
    }
}

function smolDate(a) { return a.split(" ago")[0].replace("a ", "1").replace("an ", "1").replace("days", "d").replace("day", "d").replace("hours", "h").replace("hour", "h").replace("minutes", "m").replace("minute", "m").replace("seconds", "s").replace("second", "s").replace("few", "").replace(" ", "") };

function updateStatuses(user, statuses, shouldSort=true) {
    let pageContent = document.getElementsByClassName("page-content")[0];
    let elements = document.createElement('div');

    let container = document.createElement('div');
    container.className = "status-container";
    // Render user profile
    if (user != "")
    {
        let content = document.createElement('div');
        content.className = "status-content";
        let content_html = "";
        content_html += "<div class=status-avatar style=margin:16px;background:url(" + user["icon"]["url"] + ");width:72px;height:72px;background-size:contain;background-repeat:no-repeat></div>";
        content_html += "<div class=status-header>" + user["preferredUsername"] + "<br><a href=" + user["url"] + ">@" + user["preferredUsername"] + "@" + location.host + "</a></div>"
        content_html += "<div class=status-text><font style=color:#0>" + user["summary"] + "</font></div>";
        content_html += "<div class=status-text>Joined " + new Date(Date.parse(user["published"])).toString().substr(0, 15) + "</div>";
        content.innerHTML = content_html;
        let url = document.createElement('url');
        url.textContent = window.location;
        let menuImg = document.createElement('img');
        menuImg.className = "text-menu";
        content.appendChild(menuImg);
        container.appendChild(content);
        container.appendChild(url);
        elements.appendChild(container);
        let spacer = document.createElement('div');
        spacer.style.height = "16px";
        elements.appendChild(spacer);
    }

    elements.className = "statuses";
    if (shouldSort) {
        statuses.sort((a, b) => b.id - a.id);
    }
    for (var i = 0; i < statuses.length; i++) {
        let status = statuses[i];
        if (statuses[i]["reblog"]) {
            status = statuses[i]["reblog"];
        }
        let container = document.createElement('div');
        container.className = "status-container";
        let content = document.createElement('div');
        content.className = "status-content";
        let content_html = "";
        if (statuses[i]["reblog"]) {
            content_html += "&#128640; " + statuses[i]["reblog"]["account"]["username"] + "<br><a style=\"padding-left:36px\" href=\"" + statuses[i]["reblog"]["account"]["remote_actor"] + "\">@" + statuses[i]["reblog"]["account"]["acct"] + "</a><br>";
        } else {
            if (status["visibility"] == "public") {
                content_html += "<span title=Public>&#127758;</span> ";
            }
        }
        content_html += "<span class=status-timestamp>" + smolDate(dayjs(status["created_at"]).fromNow()) + "</span><br></div>";
        content_html += "<div class=status-text>" + status["content"];
        if (!!status["media_attachments"] && status["media_attachments"].length) {
            for (var x = 0; x < status["media_attachments"].length; x++) {
                let original = status["media_attachments"][x]["meta"]["original"];
                content_html += "<img width=" + original["width"] + " height=" + original["height"] + " class=img-media src=\"" + status["media_attachments"][x]["url"] + "\"></div>";
            }
        }
        content_html += "</div>";
        if (user != "") {
            content_html += status["replies_count"] ? "<a href=" + status["url"] + ">" : "";
            content_html += "<span class=status-counts>&#128172; " + status["replies_count"] + " &#128640; " + status["reblogs_count"] + " &#11088; " + status["favourites_count"] + "</span>";
            content_html += status["replies_count"] ? "</a>" : "";
        }
        if (status["application"] && status["application"]["website"]) {
            content_html += "<div class=status-footer>via <a href=" + status["application"]["website"] + ">" + status["application"]["name"] + "</a></div>";
        }
        content.innerHTML = content_html;
        let url = document.createElement('url');
        url.textContent = status["url"];
        let menuImg = document.createElement('img');
        menuImg.className = "text-menu";
        content.appendChild(menuImg);
        container.appendChild(content);
        container.appendChild(url);
        elements.appendChild(container);
        if (i < statuses.length - 1) {
            let spacer = document.createElement('div');
            spacer.style.height = "16px";
            elements.appendChild(spacer);
        }
    }
    if (!statuses.length) {
        let container = document.createElement('div');
        container.className = "status-container";
        let content = document.createElement('div');
        content.className = "status-content";
        let content_html = "";
        content_html += "<div class=nostatus><font style=color:#0000a8>&FileRead &StatusRead &StatusPrint &ExeCmdLine <img class=text-error> No statuses found.\n " + Math.random().toFixed(6) + "s ans=0x00000000=0<br>C:/Home><img class=text-cursor></font></div>";
        content.innerHTML = content_html;
        let url = document.createElement('url');
        url.textContent = "Unnamed Task";
        let menuImg = document.createElement('img');
        menuImg.className = "text-menu";
        content.appendChild(menuImg);
        container.appendChild(content);
        container.appendChild(url);
        elements.appendChild(container);
    }
    pageContent.innerHTML = "";
    pageContent.appendChild(elements);
    updateStatusContainers();
}

function getStatuses(user) {
    fetch("https://error.checksum.fail/api/v1/accounts/" + user["accountId"] + "/statuses", {
        method: 'GET',
        headers: { 'Accept': 'application/json' }
    })
        .then(response => response.json())
        .then(data => updateStatuses(user, data));
}

function updateStatusWithReplies(user, status, replies) {
    updateStatuses(user, [status].concat(replies), false);
}

function getRepliesForStatus(user, status) {
    fetch("https://error.checksum.fail/api/v1/statuses/" + status.id + "/context", {
        method: 'GET',
        headers: { 'Accept': 'application/json' }
    })
    .then(response => response.json())
    .then(data => updateStatusWithReplies(user, status, data["descendants"]));
}

function getStatusById(id, user) {
    fetch("https://error.checksum.fail/api/v1/statuses/" + id, {
        method: 'GET',
        headers: { 'Accept': 'application/json' }
    })
    .then(response => response.json())
    .then(data => getRepliesForStatus(user, data))
}
