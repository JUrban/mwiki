function hs(obj)
{
// document.getElementById('myimage').nextSibling.style.display = 'block';
if (obj.nextSibling.style.display == 'inline')
 { obj.nextSibling.style.display = 'none'; }
else { if (obj.nextSibling.style.display == 'none')
 { obj.nextSibling.style.display = 'inline'; }
 else { obj.nextSibling.style.display = 'inline';  }}
return false;
}

function hs2(obj)
{
if (obj.nextSibling.style.display == 'block')
 { obj.nextSibling.style.display = 'none'; }
else { if (obj.nextSibling.style.display == 'none')
 { obj.nextSibling.style.display = 'block'; }
 else { obj.nextSibling.style.display = 'none';  }}
return false;
}
function hsNdiv(obj)
{
var ndiv = obj;
while (ndiv.nextSibling.nodeName != 'DIV') { ndiv = ndiv.nextSibling; }
return hs2(ndiv);
}

// explorer7 implements XMLHttpRequest in some strange way
function makeRequest(obj,url) {
        var http_request = false;
        if (window.XMLHttpRequest && !(window.ActiveXObject)) { // Mozilla, Safari,...
            http_request = new XMLHttpRequest();
            if (http_request.overrideMimeType) {
                http_request.overrideMimeType('text/xml');
            }
        } else if (window.ActiveXObject) { // IE
            try {
                http_request = new ActiveXObject('Msxml2.XMLHTTP');
            } catch (e) {
                try {
                    http_request = new ActiveXObject('Microsoft.XMLHTTP');
                } catch (e) {}
            }
        }
        if (!http_request) {
            alert('Giving up :( Cannot create an XMLHTTP instance');
            return false;
        }
        http_request.onreadystatechange = function() { insertRequest(obj,http_request); };
        http_request.open('GET', url, true);
        http_request.send(null);
    }
// commented the 200 state to have local requests too
function insertRequest(obj,http_request) {
        if (http_request.readyState == 4) {
//            if (http_request.status == 200) {
	    var ndiv = obj;
	    while (ndiv.nodeName != 'SPAN') { ndiv = ndiv.nextSibling; }
	    ndiv.innerHTML = http_request.responseText;
	    obj.onclick = function(){ return hs2(obj) };
//            } else {
//                alert('There was a problem with the request.');
//		alert(http_request.status);
//            }
	    }}
// End -->
"; }
if [$idv>0]
{
<script { @type="text/javascript";
"
<!--
var tstp_dump;
function openSoTSTP (dump) {
var tstp_url = 'http://www.cs.miami.edu/~tptp/cgi-bin/SystemOnTSTP';
var tstp_browser = window.open(tstp_url, '_blank');
tstp_dump = dump;
}
function getTSTPDump () {
return tstp_dump;
}
