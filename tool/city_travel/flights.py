"""Flight search with editable origin and dates, using the existing Trip.com affiliate account."""
import html
import json
from english_dates import SCRIPT as ENGLISH_DATES


def render(default_destination, airports):
    options = ''.join(f'<option value="{html.escape(a["code"])}" {"selected" if a["code"] == default_destination else ""}>{html.escape(a["name"])} ({html.escape(a["code"])})</option>' for a in airports)
    return '''<form id="flight-form" class="flight-form">
      <label>Trip <select id="flight-type"><option value="rt">Round trip</option><option value="ow">One way</option></select></label>
      <label>Adults <input id="flight-adults" type="number" min="1" max="9" value="1" required></label>
      <label>From <input id="flight-origin" maxlength="3" placeholder="Airport code, e.g. ICN" required pattern="[A-Za-z]{3}" autocapitalize="characters"></label>
      <label>To <select id="flight-destination">''' + options + '''</select></label>
      <label>Depart <input id="flight-depart" type="date" required></label>
      <label>Return <input id="flight-return" type="date" required></label>
      <label>Cabin <select id="flight-cabin"><option value="y">Economy</option><option value="w">Premium economy</option><option value="c">Business</option><option value="f">First</option></select></label>
      <label>Stops <select id="flight-stops"><option value="off">Any</option><option value="on">Direct only</option></select></label>
      <p class="muted fine" id="flight-summary" aria-live="polite"></p>
      <div class="fi" id="flight-insight" aria-live="polite" hidden></div>
      <p class="muted fine">Dates are departure dates at each airport, which may differ from your itinerary arrival date. Select your flight and complete payment on Trip.com.</p>
      <a class="btn" id="flight-go" href="https://www.trip.com/flights/?Allianceid=8685083&SID=319520097&trip_sub3=D1919_3743" target="_blank" rel="noopener sponsored">Search flights · Trip.com</a>
      <p class="muted fine" id="flight-status" aria-live="polite"></p>
    </form><style>.flight-form{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}.flight-form label{display:flex;flex-direction:column;gap:5px;font-size:13px}.flight-form input,.flight-form select{width:100%;min-width:0;padding:12px;border:1px solid var(--line);border-radius:12px;background:var(--surface);color:var(--ink);font:inherit}.flight-form button,.flight-form p,.flight-form a.btn{grid-column:1/-1}.flight-form a.btn{justify-self:start}#flight-origin{text-transform:uppercase}
      .fi{--fi-good:#0f6e56;--fi-good-bg:rgba(15,110,86,.12);--fi-mid:#7a5b00;--fi-mid-bg:rgba(183,121,31,.14);--fi-high:#b3261e;--fi-high-bg:rgba(196,42,31,.1);
        grid-column:1/-1;border:1px solid var(--line);border-radius:14px;padding:12px 14px;background:var(--surface);display:flex;flex-direction:column;gap:6px;font-size:14px}
      @media (prefers-color-scheme:dark){:root:not([data-theme="light"]) .fi{--fi-good:#5fd3ad;--fi-mid:#f0c060;--fi-high:#ff8a7e}}
      :root[data-theme="dark"] .fi{--fi-good:#5fd3ad;--fi-mid:#f0c060;--fi-high:#ff8a7e}
      .fi p{margin:0}.fi-head{display:flex;flex-wrap:wrap;align-items:baseline;gap:6px 10px}.fi-head b{font-size:22px;font-variant-numeric:tabular-nums}
      .fi-chip{font-size:12px;font-weight:700;padding:3px 9px;border-radius:999px}.fi-low{color:var(--fi-good);background:var(--fi-good-bg)}
      .fi-medium{color:var(--fi-mid);background:var(--fi-mid-bg)}.fi-high{color:var(--fi-high);background:var(--fi-high-bg)}
      .fi-alt{align-self:flex-start;font:inherit;font-weight:600;font-size:13px;color:var(--ink);background:transparent;border:1px solid var(--line);border-radius:999px;padding:6px 12px;cursor:pointer}
      .fi-note{font-size:12px;color:var(--muted)}</style>
    <script>(()=>{
      const el=id=>document.getElementById(id), origin=el('flight-origin'), depart=el('flight-depart'), ret=el('flight-return');
      const valid=v=>typeof v==='string' && /^[A-Z]{3}$/.test(v.toUpperCase());
      // Host integration: inject the signed-in user's Hub or pass ?hub=ICN.
      // A standalone page cannot read the Flutter app's private preferences.
      const initial=window.travelogUser?.hubIata ?? new URLSearchParams(location.search).get('hub');
      origin.value=valid(initial)?initial.toUpperCase():'';
      window.setTravelogHub=code=>{origin.value=valid(code)?code.toUpperCase():'';};
      const localISO=d=>`${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
      depart.min=localISO(new Date()); ret.min=depart.min;
      const fmt=v=>{const d=new Date(v+'T12:00');return ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'][d.getDay()]+', '
        +['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][d.getMonth()]+' '+d.getDate();};
      const sync=()=>{
        const round=el('flight-type').value==='rt';
        ret.disabled=!round; ret.required=round; ret.min=depart.value||depart.min;
        ret.setCustomValidity(round && ret.value && ret.value<depart.value?'Return must be on or after departure.':'');
        el('flight-summary').textContent=(origin.value.toUpperCase()||'Departure airport')+' → '+el('flight-destination').value
          +' · '+(depart.value?fmt(depart.value):'Choose departure date')+(round?' – '+(ret.value?fmt(ret.value):'Choose return date'):' · One way')
          +' · '+el('flight-adults').value+' adult(s) · '+el('flight-cabin').selectedOptions[0].text;
      };
      el('flight-form').addEventListener('input',sync); el('flight-form').addEventListener('change',sync); sync();
      // A real link (not window.open): published pages only let links open new tabs.
      // Its href is rebuilt on every change; a click on an incomplete form is stopped.
      const go=el('flight-go');
      // Trip.com's dcity/acity want the IATA city code plus dairport/aairport for the airport
      // (dcity=icn alone leaves "Leaving from" empty). Multi-airport cities have their own
      // metropolitan code; elsewhere the city code equals the airport code (AUH, BKK, SIN...).
      const METRO={ICN:'SEL',GMP:'SEL',NRT:'TYO',HND:'TYO',KIX:'OSA',ITM:'OSA',PEK:'BJS',PKX:'BJS',PVG:'SHA',TSA:'TPE',DMK:'BKK',CGK:'JKT',HLP:'JKT',
        LHR:'LON',LGW:'LON',STN:'LON',LTN:'LON',LCY:'LON',SEN:'LON',CDG:'PAR',ORY:'PAR',BVA:'PAR',MXP:'MIL',LIN:'MIL',BGY:'MIL',FCO:'ROM',CIA:'ROM',
        ARN:'STO',BMA:'STO',SVO:'MOW',DME:'MOW',VKO:'MOW',SAW:'IST',CRL:'BRU',JFK:'NYC',LGA:'NYC',EWR:'NYC',IAD:'WAS',DCA:'WAS',BWI:'WAS',
        ORD:'CHI',MDW:'CHI',YYZ:'YTO',YTZ:'YTO',YUL:'YMQ',GRU:'SAO',CGH:'SAO',VCP:'SAO',GIG:'RIO',SDU:'RIO',EZE:'BUE',AEP:'BUE',DWC:'DXB'};
      const city=code=>(METRO[code]||code).toLowerCase();
      const buildUrl=()=>{
        const o=origin.value.trim().toUpperCase(), d=el('flight-destination').value.toUpperCase();
        const q=new URLSearchParams({dcity:city(o),dairport:o.toLowerCase(),acity:city(d),aairport:d.toLowerCase(),ddate:depart.value,triptype:ret.disabled?'ow':'rt',class:el('flight-cabin').value,quantity:el('flight-adults').value,lowpricesource:'searchform',searchboxarg:'t',nonstoponly:el('flight-stops').value,sort:'price',Allianceid:'8685083',SID:'319520097',trip_sub1:'',trip_sub3:'D1919_3743'});
        if(!ret.disabled)q.set('rdate',ret.value);
        go.href='https://www.trip.com/flights/showfarefirst?'+q.toString();
      };
      el('flight-form').addEventListener('input',buildUrl); el('flight-form').addEventListener('change',buildUrl); buildUrl();
      const check=()=>{origin.value=origin.value.trim().toUpperCase(); sync(); buildUrl();
        const dest=el('flight-destination').value;
        if(!valid(origin.value)||!valid(dest)||origin.value===dest){el('flight-status').textContent='Choose different departure and arrival airports.';return false;}
        if(!el('flight-form').reportValidity())return false;
        el('flight-status').textContent='Opening your route and dates on Trip.com.'; return true;};
      // Fare insight: approximate fare for the departure date and how cheap it is, from the
      // getFlightInsight Cloud Function (Skyscanner price calendar, cached per route per day).
      // Exact fares stay on Trip.com. Where the function can't be reached (e.g. a published
      // page, which blocks outside requests) the box just stays hidden.
      const INSIGHT_URL='https://us-central1-proboscis-2025.cloudfunctions.net/getFlightInsight';
      const box=el('flight-insight'), LEVEL={low:'Good price',medium:'Typical price',high:'Higher than usual'};
      const usd=v=>'$'+Math.round(v).toLocaleString('en-US');
      const setDepart=iso=>{const [y,m,d]=iso.split('-'); const w=depart.nextElementSibling;
        if(w&&w.classList.contains('english-date')){const [ms,ds,ys]=w.querySelectorAll('select'); ms.value=String(+m); ds.value=String(+d); ys.value=y; ys.dispatchEvent(new Event('change',{bubbles:true}));}
        else{depart.value=iso; depart.dispatchEvent(new Event('input',{bubbles:true}));}};
      let timer, seq=0, lastKey='';
      const insight=()=>{clearTimeout(timer); timer=setTimeout(async()=>{
        const o=origin.value.trim().toUpperCase(), d=el('flight-destination').value.toUpperCase(), dt=depart.value, key=o+d+dt;
        if(!valid(o)||!valid(d)||o===d||!dt){box.hidden=true; lastKey=''; return;}
        if(key===lastKey)return; lastKey=key; const my=++seq;
        box.hidden=false; box.innerHTML='<p class="fi-note">Checking typical fares for this route…</p>';
        try{
          const r=await fetch(INSIGHT_URL,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({data:{originIata:o,destinationIata:d,date:dt}})});
          const x=(await r.json()).result; if(my!==seq)return;
          if(!r.ok||!x)throw new Error('no result');
          if(!x.found){box.innerHTML='<p>No fare estimate for this date yet. Check live fares on Trip.com.</p>'; return;}
          box.innerHTML='<div class="fi-head"><span class="fi-chip fi-'+x.level+'">'+LEVEL[x.level]+'</span><b>≈ '+usd(x.price)+'</b><span class="fi-note">cheapest one-way fare seen for '+fmt(x.date)+'</span></div>'
            +'<p>Cheaper than '+x.cheaperThanPct+'% of days around this date'+(x.vsMonthLowPct>0?' · '+x.vsMonthLowPct+'% above the low of '+usd(x.monthLow.price)+' on '+fmt(x.monthLow.date):' · the lowest fare this month')+'</p>'
            +(x.betterNearby?'<button type="button" class="fi-alt" data-date="'+x.betterNearby.date+'">Fly '+fmt(x.betterNearby.date)+' instead · ≈ '+usd(x.betterNearby.price)+'</button>':'')
            +'<p class="fi-note">Estimate from Skyscanner fare data (economy, per adult). Exact fares and seats are on Trip.com.</p>';
        }catch(_){ if(my===seq){box.hidden=true; lastKey='';} }
      },600);};
      box.addEventListener('click',e=>{const b=e.target.closest('.fi-alt'); if(b)setDepart(b.dataset.date);});
      el('flight-form').addEventListener('input',insight); el('flight-form').addEventListener('change',insight); insight();
      go.addEventListener('click',e=>{if(!check())e.preventDefault();});
      el('flight-form').addEventListener('submit',e=>{e.preventDefault(); if(check())go.click();});
    })();</script>''' + ENGLISH_DATES
