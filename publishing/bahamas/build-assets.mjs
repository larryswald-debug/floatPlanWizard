// Run from the FPW repository root: node publishing/bahamas/build-assets.mjs
// Uses checked-in public-domain context geometry; no network, dependencies, tiles or chart images.
import fs from "node:fs";
import path from "node:path";
import {fileURLToPath} from "node:url";
const here=path.dirname(fileURLToPath(import.meta.url));
const root=path.resolve(here,"../..");
const manifest=JSON.parse(fs.readFileSync(path.join(here,"templates/fort-lauderdale-bimini-v1.json"),"utf8"));
const regionGeo=JSON.parse(fs.readFileSync(path.join(here,"maps/natural-earth-context.geojson"),"utf8"));
const labels=JSON.parse(fs.readFileSync(path.join(here,"maps/region-labels.json"),"utf8")).labels;
const load=key=>key==="regionGeo"?regionGeo:undefined;
const out=name=>path.join(root,"assets/images/boating-guides/bahamas",name);
function mapSVG(box,width,height,title,desc,markers,drawLine=false,scaleNm=100){
const [minLon,minLat,maxLon,maxLat]=box;
const x=lon=>40+(lon-minLon)/(maxLon-minLon)*(width-80),y=lat=>55+(maxLat-lat)/(maxLat-minLat)*(height-110);
const pathGeom=g=>{const polys=g.type==="Polygon"?[g.coordinates]:g.coordinates;return polys.map(poly=>poly.map(ring=>ring.map((p,i)=>(i?"L":"M")+x(p[0]).toFixed(2)+","+y(p[1]).toFixed(2)).join(" ")+"Z").join(" ")).join(" ");};
let s=`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}" role="img" aria-labelledby="map-title map-desc"><title id="map-title">${title}</title><desc id="map-desc">${desc}</desc><defs><clipPath id="map-clip"><rect x="40" y="55" width="${width-80}" height="${height-110}" rx="8"/></clipPath></defs><rect width="${width}" height="${height}" fill="#edf6f7" rx="12"/><text x="24" y="29" font-family="sans-serif" font-size="24" font-weight="700" fill="#153e4a">${title}</text><g clip-path="url(#map-clip)">`;
for(let lat=Math.ceil(minLat);lat<maxLat;lat++)s+=`<path d="M40 ${y(lat)}H${width-40}" stroke="#c5dade" stroke-width="1"/><text x="44" y="${y(lat)-5}" font-family="sans-serif" font-size="18" fill="#526f78">${lat}°N</text>`;
for(let lon=Math.ceil(minLon);lon<maxLon;lon++)s+=`<path d="M${x(lon)} 55V${height-55}" stroke="#c5dade" stroke-width="1"/>`;
for(const f of load("regionGeo").features)s+=`<path d="${pathGeom(f.geometry)}" fill="#d5d6bc" stroke="#788e83" stroke-width="1"/>`;
if(drawLine&&markers.length===2)s+=`<path d="M${x(markers[0].lon)} ${y(markers[0].lat)}L${x(markers[1].lon)} ${y(markers[1].lat)}" fill="none" stroke="#9a5f29" stroke-width="3" stroke-dasharray="9 7"/>`;
s+="</g>";
for(const [i,m] of markers.entries()){s+=`<g><circle cx="${x(m.lon)}" cy="${y(m.lat)}" r="16" fill="#0d5564" stroke="#fff" stroke-width="2"/><text x="${x(m.lon)}" y="${y(m.lat)+4}" text-anchor="middle" font-family="sans-serif" font-size="17" font-weight="700" fill="white">${i+1}</text><text x="${x(m.lon)+(m.dx||18)}" y="${y(m.lat)+(m.dy||4)}" text-anchor="${m.anchor||"start"}" font-family="sans-serif" font-size="20" font-weight="700" fill="#123e49" paint-order="stroke" stroke="#edf6f7" stroke-width="4">${m.name}</text></g>`;}
const scaleLen=(scaleNm/60)/Math.cos(((minLat+maxLat)/2)*Math.PI/180)/(maxLon-minLon)*(width-80);
s+=`<path d="M${width-45-scaleLen} ${height-36}h${scaleLen}" stroke="#153e4a" stroke-width="3"/><text x="${width-45-scaleLen/2}" y="${height-16}" text-anchor="middle" font-family="sans-serif" font-size="18" fill="#153e4a">Approx. ${scaleNm} nm at centre</text><text x="24" y="${height-30}" font-family="sans-serif" font-size="18" fill="#526f78">Regional context • North is up • Not for navigation</text></svg>`;
return s;
}
fs.writeFileSync(out("regional-overview.svg"),mapSVG([-82.5,22,-74,28.5],1000,700,"Bahamas cruising areas — geographic context","Numbered regional labels match the visible HTML comparison. Geographic context only, not navigational waypoints.",labels)+"\n");
const markers=manifest.stops.map((s,i)=>({name:i?"Brown’s Marina · Bimini":"Port Everglades · PE buoy",lat:s.latitude,lon:s.longitude,dx:i?-18:18,dy:i?28:-18,anchor:i?"end":"start"}));
fs.writeFileSync(out("bimini-context.svg"),mapSVG([-80.32,25.57,-79.08,26.22],1000,560,"Port Everglades–Bimini destination references","Two source-backed reference points with a dashed schematic connection. Source datum limitations apply. Not a navigational route or distance measurement.",markers,true,20)+"\n");
const w=manifest.worksheet,total=w.legs.reduce((sum,l)=>sum+l.distance_nm,0);
const compare=[[w.planning_speed_kn,w.underway_burn_us_gph],[w.slow_speed_kn,w.slow_burn_us_gph]].map(([speed,burn])=>({speed,burn,hours:total/speed,fuel:total/speed*burn*(1+w.reserve_pct/100)}));
const text=(x,y,value,size=21)=>'<text x="'+x+'" y="'+y+'" font-family="sans-serif" font-size="'+size+'" fill="#173f49">'+value+'</text>';
let chart='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 560 620" role="img" aria-labelledby="chart-title chart-desc"><title id="chart-title">Illustrative time and fuel comparison</title><desc id="chart-desc">Independent speed and consumption assumptions for the same illustrative mileage. Separate time and fuel scales. The HTML worksheet supplies every value and the reserve method.</desc><rect width="560" height="620" fill="#f3f7f5" rx="12"/>';
chart+=text(24,36,total+' nm illustration: two operating points',24)+text(24,72,compare.map(c=>c.speed+' kn at '+c.burn+' US gal/h').join(' • '),21)+text(24,116,'Underway time estimate',23);
compare.forEach((c,i)=>{const y=142+i*72,timeWidth=c.hours/Math.max(...compare.map(point=>point.hours))*320;const minutes=Math.round(c.hours*60);chart+=text(24,y+20,c.speed+' kn',21)+'<rect x="96" y="'+y+'" width="'+timeWidth+'" height="28" rx="3" fill="#0f6775"/>'+text(96,y+52,Math.floor(minutes/60)+' h '+String(minutes%60).padStart(2,'0')+' min',20);});
chart+=text(24,318,'Fuel estimate with '+w.reserve_pct+'% added reserve',23);
compare.forEach((c,i)=>{const y=344+i*72,fuelWidth=c.fuel/Math.max(...compare.map(point=>point.fuel))*320;chart+=text(24,y+20,c.speed+' kn',21)+'<rect x="96" y="'+y+'" width="'+fuelWidth+'" height="28" rx="3" fill="#a7742f"/>'+text(96,y+52,c.fuel.toFixed(1)+' US gal',20);});
chart+=text(24,525,'Separate scales; each burn rate is assumed.',20)+text(24,555,'Slowing a boat does not promise this saving.',20)+text(24,585,'Illustrative estimates • No idle/auxiliary burn',20)+'</svg>\n';
fs.writeFileSync(out("time-fuel-comparison.svg"),chart);
const crossing='<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 560 500" role="img" aria-labelledby="stream-title stream-desc"><title id="stream-title">Crossing decisions: schematic, not a forecast</title><desc id="stream-desc">A general northward Florida Current arrow between Florida and the Bahamas. Check wind and waves, passage duration and waiting alternatives. This diagram supplies no heading correction, current speed or navigation track.</desc><defs><marker id="arrow" markerWidth="4" markerHeight="4" refX="2" refY="2" orient="auto"><path d="M0 0L4 2L0 4Z" fill="#388b96"/></marker></defs><rect width="560" height="500" rx="12" fill="#edf6f7"/><g font-family="sans-serif" fill="#173f49"><text x="24" y="36" font-size="24" font-weight="700">Consider the crossing as a whole</text><text x="24" y="76" font-size="20">Schematic only • Not to scale</text><text x="30" y="168" font-size="23">Florida</text><text x="355" y="168" font-size="23">The Bahamas</text><path d="M265 220V140" stroke="#388b96" stroke-width="16" marker-end="url(#arrow)"/><text x="24" y="270" font-size="22">General northward Florida Current flow</text><text x="24" y="302" font-size="20">Position and conditions vary.</text><text x="24" y="350" font-size="22">1. Check current wind and wave forecasts.</text><text x="24" y="386" font-size="22">2. Allow time for the reviewed water path.</text><text x="24" y="422" font-size="22">3. Keep a waiting-day alternative.</text><text x="24" y="470" font-size="20">No course compensation • NOAA / NWS context</text></g></svg>\n';
fs.writeFileSync(out("crossing-decisions.svg"),crossing);

