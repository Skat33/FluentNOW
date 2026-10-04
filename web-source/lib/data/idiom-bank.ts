import { extraIdioms } from "./idiom-expansion";
import type { PracticeQuestion } from "../tutor-types";
// At A1–A2 these are useful fixed conversational phrases, not advanced idioms.
const rows: Record<string, [string,string,string,string][]> = {
  A1: [
    ["You're welcome","Thanks for the tea! — You're welcome.","Nie ma za co","To uprzejma odpowiedź na podziękowanie."],
    ["See you","I have to go now. See you tomorrow!","Do zobaczenia","To pożegnanie, nie prośba o patrzenie."],
    ["Have fun","Enjoy the party. Have fun!","Baw się dobrze","Życzymy komuś miłego spędzenia czasu."],
    ["Of course","Can I sit here? — Of course.","Oczywiście","Wyrażamy zgodę w uprzejmy i naturalny sposób."],
    ["Excuse me","Excuse me, where is the bus stop?","Przepraszam","Przyciągamy uwagę przed zadaniem pytania."],
    ["No problem","Can you help me carry this? — No problem.","Nie ma problemu","Informujemy, że chętnie pomożemy."],
  ],
  A2: [
    ["Take your time","Take your time. Our train leaves in an hour.","Nie spiesz się","Rozmówca nie musi się spieszyć; czasu jest wystarczająco dużo."],
    ["Keep in touch","It was great working with you. Let's keep in touch.","Pozostać w kontakcie","Chodzi o dalszą wymianę wiadomości lub spotkania."],
    ["Give me a hand","This box is heavy. Could you give me a hand?","Pomóc mi","To potoczna prośba o pomoc, nie o dosłowne podanie dłoni."],
    ["Right away","The customer needs help. I'll go right away.","Od razu","Czynność nastąpi natychmiast, bez zwłoki."],
    ["Never mind","I found my glasses. Never mind, you don't need to look.","Nieważne","Wycofujemy prośbę, bo problem już zniknął."],
    ["Sounds good","How about lunch at noon? — Sounds good.","Brzmi dobrze","To naturalna akceptacja propozycji."],
  ],
  B1: [
    ["Break the ice","The teacher told a funny story to break the ice.","Przełamać pierwsze lody","Humor zmniejszył skrępowanie na początku spotkania."],
    ["Under the weather","I'm feeling under the weather, so I'll stay home.","Czuć się niewyraźnie","Mówimy o gorszym samopoczuciu, nie o pogodzie."],
    ["A piece of cake","After all that practice, the driving test was a piece of cake.","Coś bardzo łatwego","Zadanie okazało się łatwe; nie chodzi o jedzenie."],
    ["On the same page","Let's check the plan so we're all on the same page.","Tak samo rozumieć sytuację","Zespół chce mieć wspólne ustalenia i rozumienie planu."],
    ["Get the hang of","After a few lessons, I got the hang of using the camera.","Załapać, jak coś działa","Umiejętność pojawia się dzięki próbom i praktyce."],
    ["Once in a blue moon","We live far apart and meet once in a blue moon.","Bardzo rzadko","Spotkania są sporadyczne, nie zależą od faz Księżyca."],
  ],
  B2: [
    ["Cut corners","The repairs failed because the builder cut corners.","Iść na skróty kosztem jakości","Oszczędzono czas lub pieniądze, pomijając potrzebną pracę."],
    ["The ball is in your court","I've sent my proposal. The ball is in your court now.","Teraz ruch należy do ciebie","Następna decyzja lub działanie należy do rozmówcy."],
    ["Bite the bullet","I hate paperwork, but I have to bite the bullet and finish it.","Zrobić coś trudnego mimo niechęci","Akceptujemy nieprzyjemne, lecz konieczne zadanie."],
    ["A blessing in disguise","Missing that bus was a blessing in disguise: I met an old friend.","Pozorne nieszczęście, które wyszło na dobre","Nieprzyjemne zdarzenie przyniosło później korzyść."],
    ["Hit the nail on the head","Your explanation hit the nail on the head: the schedule is unrealistic.","Trafić w sedno","Wyjaśnienie celnie wskazało właściwy problem."],
    ["Read between the lines","Read between the lines of her reply; she is clearly worried.","Czytać między wierszami","Wnioskujemy z tego, co sugerowane, choć niewypowiedziane wprost."],
  ],
  C1: [
    ["Move the goalposts","Every time we meet the requirements, they move the goalposts.","Zmieniać zasady w trakcie","Oczekiwania są przesuwane mimo spełniania wcześniejszych warunków."],
    ["A double-edged sword","Flexible hours are a double-edged sword: freedom can blur work boundaries.","Coś, co ma dobre i złe strony","Ta sama cecha daje korzyść i stwarza ryzyko."],
    ["The tip of the iceberg","These complaints are only the tip of the iceberg; the issue is widespread.","Mała widoczna część większego problemu","Znane przypadki ujawniają tylko niewielką część sytuacji."],
    ["Sit on the fence","We need a decision; you can't sit on the fence forever.","Unikać opowiedzenia się po stronie","Rozmówca odkłada zajęcie jednoznacznego stanowiska."],
    ["A far cry from","The finished product is a far cry from the prototype we were shown.","Coś bardzo odmiennego od","Podkreślamy dużą różnicę między rzeczami."],
    ["Pay lip service to","The firm pays lip service to safety but never fixes the equipment.","Popierać coś tylko deklaracjami","Słowom nie towarzyszą wymagane działania."],
  ],
  C2: [
    ["Throw down the gauntlet","By challenging the industry standard, the startup threw down the gauntlet.","Rzucić wyzwanie","To stanowcze, często publiczne wyzwanie wobec przeciwnika lub ustalonego porządku."],
    ["A Pyrrhic victory","The lawsuit was a Pyrrhic victory: winning it bankrupted the company.","Zwycięstwo okupione nadmierną stratą","Koszt zwycięstwa praktycznie niweczy jego korzyści."],
    ["Hoist with his own petard","His attempt to expose a rival revealed his own fraud: he was hoist with his own petard.","Wpaść we własne sidła","Własny plan zaszkodzenia komuś obraca się przeciw jego autorowi."],
    ["Carry coals to Newcastle","Selling them more notebooks would be carrying coals to Newcastle; they manufacture them.","Robić coś zbędnego tam, gdzie tego nie brakuje","Dostarczanie rzeczy komuś, kto ma ich już pod dostatkiem, jest bezcelowe."],
    ["Set the cat among the pigeons","Her candid memo set the cat among the pigeons at headquarters.","Wywołać zamieszanie lub niepokój","Wypowiedź zaburzyła spokój grupy i wywołała silne reakcje; zwrot szczególnie brytyjski."],
    ["A curate's egg","The report is a curate's egg: excellent evidence but deeply flawed conclusions.","Coś dobrego tylko częściowo","To głównie brytyjskie określenie rzeczy o nierównej jakości."],
  ],
};
const translations: Record<string,string[]> = {
  "A1": [
    "Dziękuję za herbatę! — Nie ma za co.",
    "Muszę już iść. Do zobaczenia jutro!",
    "Miłej imprezy. Baw się dobrze!",
    "Czy mogę tu usiąść? — Oczywiście.",
    "Przepraszam, gdzie jest przystanek autobusowy?",
    "Czy pomożesz mi to przenieść? — Nie ma problemu."
  ],
  "A2": [
    "Nie spiesz się. Nasz pociąg odjeżdża za godzinę.",
    "Świetnie się z tobą pracowało. Pozostańmy w kontakcie.",
    "To pudło jest ciężkie. Czy możesz mi pomóc?",
    "Klient potrzebuje pomocy. Pójdę od razu.",
    "Znalazłem okulary. Nieważne, już nie musisz szukać.",
    "Może lunch w południe? — Brzmi dobrze."
  ],
  "B1": [
    "Nauczyciel opowiedział zabawną historię, aby przełamać pierwsze lody.",
    "Czuję się niewyraźnie, więc zostanę w domu.",
    "Po tylu ćwiczeniach egzamin na prawo jazdy był bułką z masłem.",
    "Sprawdźmy plan, żebyśmy wszyscy tak samo go rozumieli.",
    "Po kilku lekcjach załapałem, jak używać aparatu.",
    "Mieszkamy daleko od siebie i spotykamy się bardzo rzadko."
  ],
  "B2": [
    "Naprawy się nie udały, ponieważ wykonawca poszedł na skróty kosztem jakości.",
    "Wysłałem swoją propozycję. Teraz ruch należy do ciebie.",
    "Nie cierpię papierkowej roboty, ale muszę się przemóc i ją skończyć.",
    "Ucieczka tego autobusu wyszła mi na dobre: spotkałem starego znajomego.",
    "Twoje wyjaśnienie trafiło w sedno: harmonogram jest nierealistyczny.",
    "Czytaj między wierszami jej odpowiedzi; wyraźnie się martwi."
  ],
  "C1": [
    "Za każdym razem, gdy spełniamy wymagania, oni zmieniają zasady.",
    "Elastyczne godziny mają dwie strony: swoboda może zacierać granice pracy.",
    "Te skargi to tylko wierzchołek góry lodowej; problem jest powszechny.",
    "Potrzebujemy decyzji; nie możesz wiecznie unikać zajęcia stanowiska.",
    "Gotowy produkt bardzo różni się od pokazanego nam prototypu.",
    "Firma tylko deklaruje troskę o bezpieczeństwo, ale nigdy nie naprawia sprzętu."
  ],
  "C2": [
    "Kwestionując standard branżowy, startup rzucił wyzwanie konkurencji.",
    "Wygrany proces okazał się pyrrusowym zwycięstwem: doprowadził firmę do bankructwa.",
    "Próba zdemaskowania rywala ujawniła jego własne oszustwo: wpadł we własne sidła.",
    "Sprzedawanie im kolejnych notesów byłoby wożeniem drzewa do lasu; sami je produkują.",
    "Jej szczere memorandum wywołało w centrali niemałe zamieszanie.",
    "Raport jest dobry tylko częściowo: świetne dowody, lecz głęboko wadliwe wnioski."
  ]
};
export function idiomPool(level: string, variant=0): PracticeQuestion[] {
  const key=rows[level] ? level : "A2";
  const base=rows[key].map((row,index)=>({...{term:row[0],context:row[1],meaning:row[2],explanation:row[3]},translation:translations[key][index]}));
  const selected=[...base,...extraIdioms[key].map(([term,context,meaning,translation])=>({term,context,meaning,translation,explanation:`W tej sytuacji „${term}” oznacza: ${meaning.toLowerCase()}. To znaczenie wynika z całej wypowiedzi, nie z dosłownego tłumaczenia każdego słowa.`}))];
  return selected.map((row,index)=>{
    const candidates=selected.filter((_,i)=>i!==index);
    const start=(variant*5+index*3)%candidates.length;
    const wrong=[0,1,2].map(offset=>candidates[(start+offset)%candidates.length].meaning);
    return {category:"idiom",prompt:`Co oznacza „${row.term}” w tym kontekście?`,context:row.context,
      options:[row.meaning,...wrong],answer:0,explanation:row.explanation,translation:row.translation};
  });
}
