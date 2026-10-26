"""English-only date controls, independent of the browser's locale."""

SCRIPT = r'''<script>(() => {
  const months=['January','February','March','April','May','June','July','August','September','October','November','December'];
  const today=new Date(), year=today.getFullYear();
  document.querySelectorAll('input[type="date"]').forEach(input=>{
    const wrap=document.createElement('span'); wrap.className='english-date';
    const label=input.closest('label').firstChild.textContent.trim();
    const make=(name,entries)=>{
      const select=document.createElement('select'); select.setAttribute('aria-label',label+' '+name);
      select.add(new Option(name,'')); entries.forEach(([value,text])=>select.add(new Option(text,value)));
      wrap.append(select); return select;
    };
    const month=make('Month',months.map((name,i)=>[String(i+1),name]));
    const day=make('Day',Array.from({length:31},(_,i)=>[String(i+1),String(i+1)]));
    const yr=make('Year',Array.from({length:3},(_,i)=>[String(year+i),String(year+i)]));
    input.after(wrap); input.type='hidden';
    const update=()=>{
      const n=new Date(Number(yr.value),Number(month.value)-1,Number(day.value));
      const valid=yr.value&&month.value&&day.value&&n.getFullYear()===Number(yr.value)&&n.getMonth()===Number(month.value)-1&&n.getDate()===Number(day.value);
      input.value=valid?`${yr.value}-${month.value.padStart(2,'0')}-${day.value.padStart(2,'0')}`:'';
      input.dispatchEvent(new Event('input',{bubbles:true}));
      input.dispatchEvent(new Event('change',{bubbles:true}));
    };
    const validate=()=>{
      [month,day,yr].forEach(s=>{s.disabled=input.disabled;s.required=input.required&&!input.disabled});
      const invalid=Boolean(month.value&&day.value&&yr.value&&!input.value);
      day.setCustomValidity(!input.disabled&&(invalid||input.value&&input.min&&input.value<input.min)?'Choose a valid date on or after '+input.min+'.':'');
    };
    [month,day,yr].forEach(s=>s.addEventListener('change',update));
    const scope=input.closest('form') || document;
    scope.addEventListener('input',validate);
    scope.addEventListener('change',validate);
    const sync=()=>{
      // A partially selected date has no ISO value yet. Preserve the fields
      // already chosen instead of clearing them on our own change event.
      if(!input.value) return;
      const parts=input.value.split('-');
      yr.value=parts[0]||''; month.value=parts[1]?String(+parts[1]):''; day.value=parts[2]?String(+parts[2]):'';
    };
    input.addEventListener('change',sync); sync();
    validate();
  });
})();</script><style>.english-date{display:grid;grid-template-columns:1.5fr .8fr 1fr;gap:5px}.english-date select{padding:10px 4px!important;font-size:13px!important}</style>'''
