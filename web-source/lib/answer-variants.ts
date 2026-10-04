// Reviewed sense-specific variants; do not stem Polish words or guess synonyms.
// Anchors prevent bank (finance) from accepting bank (river), and preserve direction.
export function withoutDialectLabel(text: string) {
  return text.replace(/\s*\((?:AmE|BrE)\)/gi, '').trim();
}
export function answerKey(text: string) {
  return withoutDialectLabel(text).toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/ł/g,'l')
    .replace(/[’‘]/g,"'").trim().replace(/[.!?,;:]+$/g,'').replace(/\s+/g,' ');
}
export const polishSenseVariants: {term:string; variants:string[]}[] = [
 {term:'borrow',variants:['pożyczyć od kogoś','pożyczać od kogoś','pożyczyć','pożyczać','wypożyczyć','wypożyczać']},
 {term:'lend',variants:['pożyczyć komuś','pożyczać komuś','pożyczyć','pożyczać','udzielić pożyczki','udzielać pożyczki']},
 {term:'bank',variants:['brzeg rzeki','brzeg','brzeg rzeczny']},
 {term:'bank',variants:['bank','bank finansowy','instytucja finansowa']},
 {term:'say',variants:['powiedzieć coś','mówić coś','powiedzieć','mówić']},
 {term:'tell',variants:['powiedzieć','powiedzieć coś','mówić','powiedzieć komuś','powiedzieć komuś coś','powiedzieć coś komuś','mówić komuś','mówić komuś coś','poinformować','poinformować kogoś']},
 {term:'tell',variants:['opowiedzieć','opowiadać','opowiedzieć historię','opowiadać historię']},
 {term:'do',variants:['robić','zrobić','wykonywać','wykonać']},
 {term:'do',variants:['wystarczyć','wystarczać','nadawać się']},
 {term:'make',variants:['robić','zrobić','tworzyć','stworzyć','wytwarzać','wytworzyć']},
 {term:'recommend',variants:['polecić','polecać','rekomendować','zalecać','zalecić']},
 {term:'accomplish',variants:['osiągnąć','osiągać','dokonać','zrealizować','realizować']},
 {term:'achieve',variants:['osiągnąć','osiągać','zrealizować','realizować']},
 {term:'reservation',variants:['rezerwacja','zarezerwowanie']},
 {term:'appointment',variants:['umówiona wizyta','umówiona wizyta u lekarza','wizyta','termin wizyty']},
 {term:'appointment',variants:['umówione spotkanie','spotkanie','termin spotkania']},
 {term:'deadline',variants:['termin','termin wykonania','termin końcowy','ostateczny termin','termin ostateczny']},
 {term:'boarding pass',variants:['karta pokładowa','bilet pokładowy']},
 {term:'luggage',variants:['bagaż','bagaże']},
 {term:'baggage',variants:['bagaż','bagaże']},
 {term:'gate',variants:['bramka','bramka do wejścia na pokład','wyjście do samolotu','bramka wejściowa']},
 {term:'check-in',variants:['odprawa','odprawa pasażerska','odprawa na lotnisku']},
 {term:'bill',variants:['rachunek','rachunek do zapłaty']},
 {term:'check',variants:['rachunek','rachunek do zapłaty']},
 {term:'check',variants:['sprawdzić','sprawdzać','skontrolować','kontrolować']},
 {term:'receipt',variants:['paragon','potwierdzenie zapłaty','pokwitowanie']},
 {term:'cutlery',variants:['sztućce']},
 {term:'silverware',variants:['sztućce','srebrne sztućce']},
 {term:'get the hang of',variants:['załapać, jak to działa','załapać jak to działa','załapać','nabrać wprawy','opanować','załapać o co chodzi']},
 {term:'take your time',variants:['nie spiesz się','nie spieszyć się','bez pośpiechu','nie śpiesz się','nie śpieszyć się']},
 {term:'it depends',variants:['to zależy','zależy']},
 {term:'figure out',variants:['rozgryźć','rozgryzać','zrozumieć','ustalić','dojść do czegoś']},
 {term:'look for',variants:['szukać','poszukiwać']},
 {term:'look after',variants:['opiekować się','zaopiekować się','dbać o','troszczyć się o']},
 {term:'give up',variants:['poddać się','poddawać się','zrezygnować','rezygnować']},
 {term:'turn down',variants:['odrzucić','odrzucać','odmówić','odmawiać']},
 {term:'turn down',variants:['ściszyć','ściszać','zmniejszyć głośność','zmniejszać głośność']},
 {term:'break the ice',variants:['przełamać lody','przełamywać lody']},
 {term:'once in a blue moon',variants:['bardzo rzadko','od wielkiego dzwonu','raz na ruski rok']},
 {term:'under the weather',variants:['czuć się niewyraźnie','źle się czuć','czuć się źle','nie czuć się dobrze']},
 {term:'a piece of cake',variants:['bułka z masłem','łatwizna','coś bardzo łatwego','bardzo łatwe']},
];
// Explicit aspect pairs also cover older imported meanings without an AI lookup.
// No suffix stemming: e.g. zapomnieć must never become pamiętać.
export const polishAspectPairs=[
 ['kupić','kupować'],['sprzedać','sprzedawać'],['zapłacić','płacić'],['pomóc','pomagać'],
 ['przybyć','przybywać'],['przyjechać','przyjeżdżać'],['wyjść','wychodzić'],['opuścić','opuszczać'],
 ['wejść','wchodzić'],['wrócić','wracać'],['otworzyć','otwierać'],['zamknąć','zamykać'],
 ['przeczytać','czytać'],['napisać','pisać'],['odpowiedzieć','odpowiadać'],['zapytać','pytać'],
 ['zrozumieć','rozumieć'],['zapomnieć','zapominać'],['nauczyć się','uczyć się'],
 ['wybrać','wybierać'],['zdecydować','decydować'],['zdecydować się','decydować się'],
 ['zarezerwować','rezerwować'],['zamówić','zamawiać'],['odwołać','odwoływać'],['potwierdzić','potwierdzać'],
 ['sprawdzić','sprawdzać'],['wyjaśnić','wyjaśniać'],['zmienić','zmieniać'],['poprawić','poprawiać'],
 ['przygotować','przygotowywać'],['skończyć','kończyć'],['rozpocząć','rozpoczynać'],['zacząć','zaczynać'],
 ['otrzymać','otrzymywać'],['dostać','dostawać'],['wysłać','wysyłać'],['przynieść','przynosić'],
 ['zabrać','zabierać'],['oddać','oddawać'],['zwrócić','zwracać'],['zgubić','gubić'],
 ['zjeść','jeść'],['wypić','pić'],['ugotować','gotować'],['upiec','piec'],
 ['posprzątać','sprzątać'],['umyć','myć'],['naprawić','naprawiać'],['zepsuć','psuć'],
 ['odwiedzić','odwiedzać'],['spotkać','spotykać'],['poczekać','czekać'],['spróbować','próbować'],
 ['uniknąć','unikać'],['osiągnąć','osiągać'],['zaoferować','oferować'],['zgodzić się','zgadzać się'],
 ['odmówić','odmawiać'],['zauważyć','zauważać'],['zaprosić','zapraszać'],['przeprosić','przepraszać'],
];
export function polishAnswers(term:string, translation:string, saved:string[]=[]) {
 const base=[withoutDialectLabel(translation),...translation.split(/[,;/]/).map(withoutDialectLabel),...saved];
 const anchors=new Set(base.map(answerKey));
 const reviewed=polishSenseVariants.filter(s=>answerKey(s.term)===answerKey(term) && s.variants.some(v=>anchors.has(answerKey(v)))).flatMap(s=>s.variants);
 const aspects=polishAspectPairs.filter(pair=>pair.some(v=>anchors.has(answerKey(v)))).flat();
 return [...new Set([...base,...reviewed,...aspects].map(s=>s.trim()).filter(Boolean))];
}
// Unambiguous contractions only. Ambiguous 's/'d remain governed by the grammar item.
export function englishAnswerKey(value:string) {
 return answerKey(value).replace(/\bwon't\b/g,'will not').replace(/\bcan't\b/g,'cannot').replace(/\bcan not\b/g,'cannot')
 .replace(/\bshan't\b/g,'shall not').replace(/n't\b/g,' not').replace(/'re\b/g,' are').replace(/'ve\b/g,' have')
 .replace(/'ll\b/g,' will').replace(/'m\b/g,' am').replace(/\s+/g,' ').trim();
}
