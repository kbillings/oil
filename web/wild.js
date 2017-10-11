// Analytics page.
//
// DEPS: ajax.js

'use strict';

// Like the function in report.R that writes files
function filenameEscape(u) {
  // Lame: no global replace without regex
  u = u.replace(/\//g, '_2F_');
  u = u.replace(/=/g, '_3D_');
  u = u.replace(/\?/g, '_3F_');
  u = u.replace(/&/g, '_26_');
  return u;
}

// TODO: Factor out common pattern from showTop?  There should just be a
// callback to get a string.

function showTopUriLinks(hist, elementId, urlHash, max) {
  var top = hist.top;
  max = max || 5;
  var n = Math.min(top.value.length, max);
  var tableHtml = '';
  for (var i = 0; i < n; ++i) {
    var count = top.count[i].toLocaleString();
    var uri_base = top.value[i];

    var u = filenameEscape(uri_base);
    var query = urlHash.modifyAndEncode({uri_base: u});

    tableHtml += '<tr>';
    tableHtml += `<td>${count}</td>`;
    tableHtml += `<td><a href="page.html#${query}">${uri_base}</a></td>`;
    tableHtml += '</tr>';
  }
  var elem = document.getElementById(elementId).tBodies[0];
  elem.innerHTML = tableHtml;
}

function showTopAsLinks(hist, elementId, max) {
  var top = hist.top;
  max = max || 5;
  var n = Math.min(top.value.length, max);
  var tableHtml = '';
  for (var i = 0; i < n; ++i) {
    var count = top.count[i].toLocaleString();
    var value = htmlEscape(top.value[i]);

    tableHtml += '<tr>';
    tableHtml += `<td>${count}</td>`;
    tableHtml += `<td><a href="${value}">${value}</a></td>`;
    tableHtml += '</tr>';
  }
  var elem = document.getElementById(elementId).tBodies[0];
  elem.innerHTML = tableHtml;
}

function showTopAsCode(hist, elementId, max) {
  var top = hist.top;
  max = max || 5;
  var n = Math.min(top.value.length, max);
  var tableHtml = '';
  for (var i = 0; i < n; ++i) {
    var count = top.count[i].toLocaleString();
    var value = htmlEscape(top.value[i]);

    tableHtml += '<tr>';
    tableHtml += `<td>${count}</td>`;
    tableHtml += `<td><code>${value}</code></td>`;
    tableHtml += '</tr>';
  }
  var elem = document.getElementById(elementId).tBodies[0];
  elem.innerHTML = tableHtml;
}

function showSingle(single, doc) {
  for (name in single) {
    var elem = doc.getElementById(name);
    if (!elem) {
      continue;
    }
    var value = single[name];
    var s;
    if (name === 'earliest' || name === 'latest') {
      var d = new Date(value * 1000);   // milliseconds
      s = d.toString();
    } else if (name === 'uri_base') {
      s = '<a href="' + value + '">' + value + '</a>';
    } else {
      s = '<b>' + value.toLocaleString() + '</b>';
    }
    // assume it's a number
    elem.innerHTML = s;
    //console.log('Set ' + elem + ' to ' + single[name]);
  }
}

function showNavLinks(urlHash, period) {
  var r = document.getElementById('recentLink')
  var a = document.getElementById('allLink')

  if (period === 'all') {
    var query = urlHash.modifyAndEncode({period: 'recent'});
    r.innerHTML = `<a href="#${query}">recent</a>`;
    a.innerHTML = '<b>all</b>';
  } else {
    r.innerHTML = '<b>recent</b>';
    var query = urlHash.modifyAndEncode({period: 'all'});
    a.innerHTML = `<a href="#${query}">all</a>`;
  }
}

function showListing(entries, filesElem, dirsElem) {
  var tableHtml = '<tr><td>Hi</td></tr>';
  filesElem.innerHTML = tableHtml;
  dirsElem.innerHTML = tableHtml;
}

// for wild-dir.html
function initDir(locHash, tableStates, statusElem) {
  var urlHash = new UrlHash(locHash);
  var path = urlHash.get('path') || '';

  var jsonUrl = `${path}INDEX.json`;

  jsonGet(jsonUrl, statusElem, function(entries) {
    var filesElem = document.getElementById('files').tBodies[0];
    var dirsElem = document.getElementById('dirs').tBodies[0];

    showListing(entries, filesElem, dirsElem)
  });

  return;

  //showNavLinks(urlHash, period);

  //console.log(`Period: ${period}`);
  //console.log(`hash: ${location.hash}`);

  // Load the plot
  var plotElem = document.getElementById('hitsPlot');
  plotElem.src = `../analytics-data/${period}/stage3/hits.ALL.png`

  var a = document.getElementById('topUrisPlotLink');
  a.href = `../analytics-data/${period}/stage3/hits.TOP_URIS.png`

  var jsonUrl = `../analytics-data/${period}/stage3/stats.ALL.json`
  var elem = document.getElementById('underlying');
  elem.href = jsonUrl;

  jsonGet(jsonUrl, statusElem, function(stats) {
    console.log(`Links for ${period}`);
    showTopUriLinks(stats.blogHist, 'topBlog', urlHash, 40);
    showTopUriLinks(stats.downloadHist, 'topDownload', urlHash, 10);
    showTopUriLinks(stats.otherUriHist, 'topOther', urlHash, 10);
    
    showTopAsCode(stats.refererHist, 'topReferers', 10);
    showTopAsCode(stats.ipAddrHist, 'topIpAddrs');
    showTopAsCode(stats.userAgentHist, 'topUserAgents');
    showSingle(stats.single, document);
  });
}

// for page.html.
function initPage(locHash, tableStates, statusElem) {
  var urlHash = new UrlHash(locHash);
  var period = urlHash.get('period') || 'all';

  showNavLinks(urlHash, period);

  var escapedUri = urlHash.get('uri_base');
  if (escapedUri === undefined) {
    appendMessage(statusElem, "Missing URI in URL hash.");
    return;
  }

  // Load the plot
  var plotElem = document.getElementById('hitsPlot');
  plotElem.src = `../analytics-data/${period}/stage3/hits.${escapedUri}.png`

  var jsonUrl = `../analytics-data/${period}/stage3/stats.${escapedUri}.json`
  var elem = document.getElementById('underlying');
  elem.href = jsonUrl;
  elem.innerHTML = `stats.${escapedUri}.json`

  jsonGet(jsonUrl, statusElem, function(stats) {

    showTopAsCode(stats.uriRestHist, 'topUriRest', 10);
    showTopAsLinks(stats.refererHist, 'topReferers', 10);
    showTopAsCode(stats.ipAddrHist, 'topIpAddrs');
    showTopAsCode(stats.userAgentHist, 'topUserAgents');
    showSingle(stats.single, document);

  });

  // TODO:
  // - Show the actual page title!  Generate that from
  // - blog/posts.json -- blog.py should generate this

  return;

  // Add title and page element
  document.title = metricName;
  var nameElem = document.getElementById('metricName');
  nameElem.innerHTML = metricName;

}
