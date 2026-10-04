// Each level contains 15 teaching patterns. Slots are filled with bilingual
// event frames; the resulting complete 1,800 records are committed as JSON.
const cap=s=>s[0].toUpperCase()+s.slice(1);
const row=(rule,context,answer,wrong,translation,explanation,hint)=>({rule,context,answer,wrong,translation:cap(translation),explanation,hint});
const g='________';
export function patterns(level,f) {
 const {base:v,s,past:p,pp,ing,obj:o,hint:h,pl,pastPl:past,futurePl:future,infPl:inf}=f;
 const r=(rule,context,answer,wrong,translation,explanation,hint=h)=>row(rule,context.replace('G',`${g} (${hint})`),answer,wrong,translation,explanation,hint);
 const simple='Podmiot we wymaga formy podstawowej. Present Simple opisuje regularną czynność.';
 const continuous='Czynność trwa w podanym momencie: odpowiednia forma be oraz czasownik z -ing.';
 const perfect='Po have lub had potrzebny jest imiesłów przeszły (trzecia forma), a nie bezokolicznik.';
 const inv='Początkowe wyrażenie ograniczające wymaga inwersji: operator przed podmiotem. Po did używamy formy podstawowej.';
 if(level==='A1') return [
 r('present simple',`On Saturdays, we usually G ${o}.`,v,[s,ing,`are ${v}`],`W soboty zwykle ${pl}.`,simple),
 r('present simple negative',`We do not G ${o} on Sundays.`,v,[s,ing,pp===v ? `to ${v}` : pp],`W niedziele ${f.negativePl}.`,'Po do not czasownik pozostaje w formie podstawowej.'),
 r('present simple questions',`Do we G ${o} every week?`,v,[s,ing,`to ${v}`],`Czy co tydzień ${pl}?`,'Pytanie z do wymaga podstawowej formy czasownika.'),
 r('present continuous',`Look! We are G ${o} right now.`,ing,[v,s,`to ${v}`],`Spójrz! Właśnie ${pl}.`,continuous),
 r('present continuous agreement',`We G ${ing} ${o} now, so please wait.`, 'are',['is','am','be'],`Teraz ${pl}, więc proszę poczekać.`,'We łączy się z are. Is pasuje do he/she/it, a am do I.','być'),
 r('present continuous questions',`Are we G ${o} at the moment?`,ing,[v,s,`to ${v}`],`Czy w tej chwili ${pl}?`,continuous),
 r('can ability',`We can G ${o} without help.`,v,[s,`to ${v}`,ing],`Potrafimy ${inf} bez pomocy.`,'Po can używamy bezokolicznika bez to, niezależnie od osoby.'),
 r('cannot',`We cannot G ${o} without help yet.`,v,[s,`to ${v}`,ing],`Nie potrafimy jeszcze ${f.negativeInfPl} bez pomocy.`,'Cannot jest przeczeniem can. Następny czasownik ma formę podstawową.'),
 r('can questions',`Can we G ${o} together?`,v,[s,ing,`to ${v}`],`Czy możemy razem ${inf}?`,'W pytaniu can stoi przed podmiotem, a główny czasownik ma formę podstawową.'),
 r('imperative',`Please G ${o} before you leave.`,v,[s,ing,`to ${v}`],`Proszę ${inf} przed wyjściem.`,'Polecenie tworzymy za pomocą podstawowej formy czasownika, bez to.'),
 r('negative imperative',`Do not G ${o} today; wait until tomorrow.`,v,[s,ing,`to ${v}`],`Nie należy dziś ${f.negativeOngoingInfPl}; trzeba poczekać do jutra.`,'Zakaz ma konstrukcję do not + podstawowa forma czasownika.'),
 r('lets',`Let's G ${o} together this afternoon.`,v,[s,ing,`to ${v}`],`Może dziś po południu wspólnie ${future}.`,'Po let’s używamy podstawowej formy czasownika, bez to.'),
 r('want infinitive',`We want G ${o} before lunch.`,`to ${v}`,[v,ing,s],`Chcemy ${inf} przed lunchem.`,'Po want przed drugim czasownikiem potrzebne jest to.'),
 r('like gerund',`We like G ${o} together.`,ing,[s,`to ${ing}`,`are ${ing}`],`Lubimy razem ${f.ongoingInfPl}.`,'Po like może wystąpić forma -ing lub bezokolicznik z to. Spośród podanych opcji tylko forma -ing jest poprawna.'),
 r('to be',`We G ready to ${v} ${o}.`,'are',['is','am','be'],`Jesteśmy gotowi ${inf}.`,'We to liczba mnoga, dlatego używamy are.','być'),
 ];
 if(level==='A2') return [
 r('past simple',`Last Saturday, we G ${o}.`,p,[s,ing,`have ${v}`],`W zeszłą sobotę ${past}.`,'Zakończony czas last Saturday wskazuje Past Simple; używamy drugiej formy czasownika.'),
 r('past simple negative',`We did not G ${o} yesterday because we were busy.`,v,[s,ing,p===v?`to ${v}`:p],`Wczoraj ${f.negativePastPl}, bo byliśmy zajęci.`,'Did not już wyraża czas przeszły. Następny czasownik wraca do formy podstawowej.'),
 r('past simple questions',`Did we G ${o} last Friday?`,v,[s,ing,p===v?`to ${v}`:p],`Czy w zeszły piątek ${past}?`,'Po operatorze did używamy podstawowej formy czasownika.'),
 r('past continuous',`At ten yesterday, we were G ${o}.`,ing,[v,s,`to ${v}`],`Wczoraj o dziesiątej ${f.durationPl}.`,continuous),
 r('past continuous agreement',`We G ${ing} ${o} when the phone rang.`,'were',['was','are','be'],`Gdy zadzwonił telefon, ${f.durationPl}.`,'We wymaga were. Past Continuous opisuje tło dla krótkiego zdarzenia.','być'),
 r('going to',`We are going G ${o} tomorrow; that is our plan.`,`to ${v}`,[ing,s,`to ${ing}`],`Planujemy jutro ${inf}.`,'Going to łączy się z podstawową formą czasownika; po going potrzebujemy tutaj to.'),
 r('future will',`All right, we will G ${o} for you.`,v,[s,ing,`to ${v}`],`Dobrze, ${future} dla was.`,'Po will występuje forma podstawowa, bez to i końcówki -s.'),
 r('must obligation',`The instructions say we must G ${o} first.`,v,[s,ing,`to ${v}`],`Według instrukcji najpierw musimy ${inf}.`,'Po must używamy podstawowej formy czasownika bez to.'),
 r('have to',`We have G ${o} before the guests arrive.`,`to ${v}`,[s,ing,`to ${ing}`],`Musimy ${inf} przed przybyciem gości.`,'Obowiązek wyrażamy przez have to + czasownik w formie podstawowej.'),
 r('should advice',`We should G ${o} more carefully next time.`,v,[s,ing,`to ${v}`],`Następnym razem powinniśmy staranniej ${inf}.`,'Should wyraża radę i łączy się z podstawową formą czasownika.'),
 r('enjoy gerund',`We enjoy G ${o} on our days off.`,ing,[`to ${v}`,v,s],`W wolne dni lubimy ${f.ongoingInfPl}.`,'Po enjoy potrzebujemy formy -ing, nie bezokolicznika.'),
 r('would like',`We would like G ${o} this weekend.`,`to ${v}`,[ing,s,`to ${ing}`],`Chcielibyśmy w ten weekend ${inf}.`,'Would like łączy się z bezokolicznikiem z to.'),
 r('because clause',`We stayed late because we G to ${v} ${o} before leaving.`,'wanted',['wanting','wants','were want'],`Zostaliśmy dłużej, bo chcieliśmy ${inf} przed wyjściem.`,'Zdanie dotyczy przeszłości; wanted jest formą Past Simple od want.','chcieć'),
 r('past to be',`We G too tired to ${v} ${o} after the long trip.`,'were',['was','are','being'],`Po długiej podróży byliśmy zbyt zmęczeni, żeby ${inf}.`,'We w przeszłości wymaga were. Too + przymiotnik + to opisuje przeszkodę.','być'),
 r('purpose infinitive',`We came here G ${o}, not to sit and chat.`,`to ${v}`,[s,`to ${ing}`,`are ${ing}`],`Przyszliśmy tutaj, żeby ${inf}, a nie siedzieć i rozmawiać.`,'Cel czynności można wyrazić przez to + podstawowa forma czasownika.'),
 ];
 if(level==='B1') return [
 r('present perfect vs past simple',`We have already G ${o}, so that job is finished.`,pp,[s,ing,`to ${v}`],`Już ${past}, więc to zadanie jest skończone.`,perfect),
 r('present perfect questions',`Have we ever G ${o} without any help?`,pp,[s,ing,`to ${v}`],`Czy kiedykolwiek udało nam się ${inf} bez żadnej pomocy?`,perfect),
 r('present perfect negative',`We have not G ${o} yet, but we will start soon.`,pp,[s,ing,`to ${v}`],`Jeszcze ${f.negativePastPl}, ale wkrótce zaczniemy.`,perfect),
 r('past continuous',`While we were G ${o}, a neighbor came to see us.`,ing,[s,v,`to ${v}`],`Kiedy ${f.durationPl}, odwiedził nas sąsiad.`,continuous),
 r('first conditional',`If we finish early, we will G ${o} before dinner.`,v,[s,ing,`to ${v}`],`Jeśli skończymy wcześniej, przed kolacją ${future}.`,'W realnym warunku przyszłym stosujemy if + Present Simple oraz will + bezokolicznik.'),
 r('second conditional',`If we had more free time, we would G ${o} more often.`,v,[s,ing,`to ${v}`],`Gdybyśmy mieli więcej wolnego czasu, częściej moglibyśmy ${f.ongoingInfPl}.`,'Hipotetyczny skutek wyrażamy przez would + formę podstawową.'),
 r('reported speech',`Yesterday we said we G going to ${v} ${o} that afternoon.`,'were',['are','was','be'],`Wczoraj powiedzieliśmy, że zamierzamy tego popołudnia ${inf}.`,'W relacji z przeszłości are going to przesuwa się na were going to. We wymaga liczby mnogiej.','być'),
 r('used to',`When we lived nearby, we used G ${o} every week.`,`to ${v}`,[ing,s,`to ${ing}`],`Kiedy mieszkaliśmy w pobliżu, mieliśmy zwyczaj co tydzień ${f.ongoingInfPl}.`,'Used to + forma podstawowa opisuje dawny zwyczaj.'),
 r('be used to',`We are used to G ${o} without anyone supervising us.`,ing,[v,s,`to ${v}`],`Przywykliśmy już do tego, że bez nadzoru ${pl}.`,'W be used to słowo to jest przyimkiem, dlatego po nim potrzebujemy -ing.'),
 r('simple passive',`We were asked G ${o} before the visitors arrived.`,`to ${v}`,[v,s,`to ${ing}`],`Poproszono nas, żeby ${inf} przed przybyciem gości.`,'W stronie biernej konstrukcja ask someone to do zmienia się na be asked to do.'),
 r('gerund after preposition',`We talked about G ${o} during the next visit.`,ing,[v,s,`to ${v}`],`Rozmawialiśmy o planie, żeby ${inf} podczas następnej wizyty.`,'Po przyimku about czasownik występuje w formie -ing.'),
 r('decide infinitive',`We decided G ${o} before taking a break.`,`to ${v}`,[ing,s,`to ${ing}`],`Postanowiliśmy ${inf} przed przerwą.`,'Decide łączy się z bezokolicznikiem z to.'),
 r('let bare infinitive',`They let us G ${o} on our own.`,v,[s,ing,`to ${v}`],`Pozwolili nam samodzielnie ${inf}.`,'Po let + osoba używamy bezokolicznika bez to.'),
 r('make bare infinitive',`The supervisor made us G ${o} again.`,v,[s,ing,`to ${v}`],`Przełożony kazał nam ponownie ${inf}.`,'W stronie czynnej make + osoba wymaga bezokolicznika bez to.'),
 r('will vs going to',`We have made a plan: we are going G ${o} next Monday.`,`to ${v}`,[s,ing,`to ${ing}`],`Ustaliliśmy plan: w przyszły poniedziałek zamierzamy ${inf}.`,'Zaplanowany zamiar wyrażamy przez be going to + forma podstawowa.'),
 ];
 if(level==='B2') return [
 r('past perfect',`By the time the director arrived, we had already G ${o}.`,pp,[s,ing,`to ${v}`],`Zanim przyjechał dyrektor, już ${past}.`,perfect),
 r('past perfect continuous',`We had been G ${o} for hours when the supervisor finally arrived.`,ing,[v,pp===v?s:pp,`to ${v}`],`Kiedy przełożony wreszcie przyjechał, od wielu godzin ${f.durationPl}.`,'Had been + -ing podkreśla czas trwania czynności przed innym zdarzeniem przeszłym.'),
 r('present perfect continuous',`We have been G ${o} all morning and still have more work to do.`,ing,[v,s,`to ${v}`],`Od rana ${pl} i wciąż mamy jeszcze sporo do zrobienia.`,'Have been + -ing łączy wcześniejszy początek czynności z jej trwaniem do teraz.'),
 r('third conditional',`If we had had enough time yesterday, we would have G ${o}.`,pp,[s,ing,`to ${v}`],`Gdybyśmy wczoraj mieli dość czasu, udałoby nam się ${inf}.`,'Nierealny skutek przeszły wymaga would have + imiesłów.'),
 r('past modals',`We should have G ${o} earlier; leaving it until today was a mistake.`,pp,[s,ing,`to ${v}`],`Powinniśmy byli wcześniej ${inf}; odkładanie tego do dziś było błędem.`,'Should have + imiesłów wyraża krytyczną ocenę niezrealizowanej czynności przeszłej.'),
 r('past modals possibility',`We could have G ${o} yesterday, but we chose to wait.`,pp,[s,ing,`to ${v}`],`Mogliśmy wczoraj ${inf}, ale postanowiliśmy poczekać.`,'Could have + imiesłów opisuje niewykorzystaną możliwość w przeszłości.'),
 r('gerund vs infinitive',`We admitted G ${o} without the necessary permission.`,ing,[v,s,`to ${v}`],`Przyznaliśmy, że bez niezbędnego pozwolenia ${past}.`,'Po admit używamy formy -ing. Możliwe jest też having + imiesłów, gdy podkreślamy wcześniejsze zdarzenie.'),
 r('gerund after deny',`We denied G ${o} while the office was closed.`,ing,[v,s,`to ${v}`],`Zaprzeczyliśmy, jakoby podczas zamknięcia biura zdarzyło nam się ${inf}.`,'Deny łączy się z formą -ing, nie z bezokolicznikiem z to.'),
 r('perfect infinitive',`We appear to have G ${o} without consulting the rest of the team.`,pp,[s,ing,`to ${v}`],`Wygląda na to, że ${past}, nie konsultując tego z resztą zespołu.`,'To have + imiesłów opisuje czynność wcześniejszą niż obecna ocena z appear.'),
 r('future perfect',`By this time tomorrow, we will have G ${o}.`,pp,[s,ing,`to ${v}`],`Do jutra o tej porze ${future}.`,'Future Perfect: will have + imiesłów, dla czynności zakończonej przed określonym przyszłym momentem.'),
 r('future continuous',`At this time tomorrow, we will be G ${o}, so please call later.`,ing,[v,s,`to ${v}`],`Jutro o tej porze będziemy ${f.ongoingInfPl}, więc zadzwoń później.`,'Will be + -ing opisuje czynność trwającą w przyszłym momencie.'),
 r('passive infinitive',`We were required G ${o} again before the inspection.`,`to ${v}`,[v,s,`to ${ing}`],`Zobowiązano nas, żeby ponownie ${inf} przed kontrolą.`,'W konstrukcji be required to do wymagany jest bezokolicznik z to.'),
 r('perfect gerund',`We regretted not having G ${o} when we had the chance.`,pp,[s,ing,`to ${v}`],`Żałowaliśmy, że ${f.negativePastPl}, kiedy była okazja.`,'Having + imiesłów po regret podkreśla zdarzenie wcześniejsze; not przeczy tej wcześniejszej czynności.'),
 r('would rather',`We would rather G ${o} now than leave everything until tomorrow.`,v,[s,ing,`to ${v}`],`Wolelibyśmy teraz ${inf}, niż zostawić wszystko na jutro.`,'Po would rather, gdy podmiot się nie zmienia, używamy bezokolicznika bez to.'),
 r('had better',`We had better G ${o} before the deadline expires.`,v,[s,ing,`to ${v}`],`Lepiej, żebyśmy zdążyli ${inf} przed upływem terminu.`,'Had better + forma podstawowa wyraża mocną radę dotyczącą teraźniejszości lub przyszłości.'),
 ];
 if(level==='C1') return [
 r('inversion',`Only after receiving written authorization did we G ${o}.`,v,[s,ing,p===v?`to ${v}`:p],`Dopiero po otrzymaniu pisemnego upoważnienia ${past}.`,inv),
 r('inversion perfect',`Never before had we G ${o} under such intense scrutiny.`,pp,[s,ing,`to ${v}`],`Nigdy wcześniej ${f.negativePastPl} pod tak ścisłą kontrolą.`,inv+' '+perfect),
 r('subjunctive',`The committee insisted that we G ${o} before making any public statement.`,v,[s,ing,`to ${v}`],`Komisja zażądała, żebyśmy najpierw zdołali ${inf}, a dopiero później wydali oświadczenie.`,'Mandative subjunctive po żądaniu wymaga podstawowej formy czasownika. Wariant should + bezokolicznik też bywa poprawny.'),
 r('mixed conditionals',`If we had obtained funding last year, we would be G ${o} now.`,ing,[v,s,`to ${v}`],`Gdybyśmy w zeszłym roku uzyskali finansowanie, obecnie moglibyśmy ${inf}.`,'Przeszły warunek łączy się z obecnym, trwającym skutkiem: would be + -ing.'),
 r('mixed conditionals past result',`If we were less cautious by nature, we would have G ${o} last month.`,pp,[s,ing,`to ${v}`],`Gdybyśmy z natury byli mniej ostrożni, już w zeszłym miesiącu moglibyśmy ${inf}.`,'Stała cecha łączy się z niezrealizowanym skutkiem w przeszłości: would have + imiesłów.'),
 r('emphatic structures',`What we did next was G ${o}, rather than wait for another report.`,v,[s,ing,`are ${v}`],`Następnie ${past}, zamiast czekać na kolejny raport.`,'W zdaniu rozszczepionym What we did was możliwa jest forma podstawowa (także to + bezokolicznik).'),
 r('advanced passive',`We are believed to have G ${o} before the inquiry began.`,pp,[s,ing,`to ${v}`],`Uważa się, że przed rozpoczęciem dochodzenia ${past}.`,'Reporting passive + dokonany bezokolicznik wskazuje czynność wcześniejszą: are believed to have + imiesłów.'),
 r('negative infinitive',`We were explicitly instructed not G ${o} without an independent observer.`,`to ${v}`,[s,`to ${ing}`,`are ${ing}`],`Wyraźnie polecono nam nie ${f.negativeOngoingInfPl} bez niezależnego obserwatora.`,'Przeczenie bezokolicznika ma postać not to + forma podstawowa.'),
 r('perfect participle',`Having G ${o}, we were finally able to publish our findings.`,pp,[s,`to ${v}`,`have ${v}`],`Gdy już ${past}, mogliśmy wreszcie opublikować ustalenia.`,'Having + imiesłów tworzy skrócone zdanie opisujące czynność wcześniejszą. Jego wykonawcą jest podmiot we.'),
 r('inversion conditional',`Had we G ${o} sooner, the outcome might have been different.`,pp,[s,ing,`to ${v}`],`Gdyby udało nam się wcześniej ${inf}, wynik mógłby być inny.`,'Had + podmiot + imiesłów zastępuje if + Past Perfect.'),
 r('inversion future condition',`Should we G ${o} again, we will invite an external specialist.`,v,[s,ing,`to ${v}`],`Gdybyśmy ponownie mieli ${inf}, zaprosimy zewnętrznego specjalistę.`,'Should + podmiot + forma podstawowa wyraża formalny warunek przyszły.'),
 r('passive causation',`We were made G ${o} twice, despite our objections.`,`to ${v}`,[v,s,`to ${ing}`],`Mimo naszych zastrzeżeń zmuszono nas, żeby dwukrotnie ${inf}.`,'W stronie biernej make przyjmuje to: be made to do, w przeciwieństwie do czynnego make someone do.'),
 r('concessive clause',`Although we had G ${o} thoroughly, the panel requested a second assessment.`,pp,[s,ing,`to ${v}`],`Chociaż dokładnie ${past}, komisja poprosiła o ponowną ocenę.`,'Although wprowadza ustępstwo; had + imiesłów wskazuje czynność wcześniejszą niż prośba komisji.'),
 r('modal perfect continuous',`We must have been G ${o} for hours, judging by how exhausted everyone looked.`,ing,[v,s,`to ${v}`],`Sądząc po wyczerpaniu wszystkich, musieliśmy godzinami ${f.ongoingInfPl}.`,'Must have been + -ing to wniosek o czynności trwającej w przeszłości.'),
 r('preference different subject',`The director would rather we G ${o} tomorrow, not today.`,p,[s,ing,`to ${v}`],`Dyrektor wolałby, żebyśmy jutro, a nie dziś, zdołali ${inf}.`,'Po would rather z innym podmiotem używamy Past Simple, nawet jeśli życzenie dotyczy przyszłości.'),
 ];
 return [
 r('inversion not until',`Not until the last objection had been withdrawn did we G ${o}.`,v,[s,ing,p===v?`to ${v}`:p],`Dopiero gdy wycofano ostatnie zastrzeżenie, ${past}.`,'Not until na początku wywołuje inwersję w zdaniu głównym, nie w zdaniu po until. Po did jest forma podstawowa.'),
 r('inversion no sooner',`No sooner had we G ${o} than the findings were challenged on procedural grounds.`,pp,[s,ing,`to ${v}`],`Ledwie ${past}, ustalenia zakwestionowano ze względów proceduralnych.`,'No sooner łączy się z than. Inwersja z had i imiesłów pokazują bezpośrednie następstwo przeszłych zdarzeń.'),
 r('inversion hardly',`Hardly had we G ${o} when a previously undisclosed document came to light.`,pp,[s,ing,`to ${v}`],`Ledwie ${past}, ujawniono wcześniej nieznany dokument.`,'Hardly + inwersja z Past Perfect łączy się z when, nie z than.'),
 r('subjunctive negative',`It was stipulated that we not G ${o} until all conflicts of interest had been declared.`,v,[s,ing,`to ${v}`],`Zastrzeżono, że nie wolno nam ${f.negativeOngoingInfPl} przed ujawnieniem wszystkich konfliktów interesów.`,'W amerykańskim przeczącym subjunctive not stoi bezpośrednio przed formą podstawową, bez do.'),
 r('mixed conditionals inversion',`Were we not bound by confidentiality, we would have G ${o} publicly last year.`,pp,[s,ing,`to ${v}`],`Gdyby nie obowiązywała nas poufność, moglibyśmy publicznie ${inf} już w zeszłym roku.`,'Were we not zastępuje if we were not. Obecne ograniczenie łączy się z niezrealizowanym skutkiem przeszłym: would have + imiesłów.'),
 r('counterfactual continuous',`Had the embargo been lifted, we would now be G ${o} with our overseas counterparts.`,ing,[v,s,`to ${v}`],`Gdyby zniesiono embargo, moglibyśmy teraz wspólnie z zagranicznymi partnerami ${inf}.`,'Warunek ma bierny Past Perfect z inwersją, a bieżący hipotetyczny skutek przyjmuje would now be + -ing.'),
 r('advanced passive perfect continuous',`We are understood to have been G ${o} long before the controversy became public.`,ing,[v,s,`to ${v}`],`Według dostępnych informacji ${f.durationPl} na długo przed ujawnieniem kontrowersji.`,'Reporting passive łączy się tu z perfect continuous infinitive: to have been + -ing. Akcent pada na wcześniejsze trwanie.'),
 r('emphatic structures restriction',`All we could reasonably have done was G ${o} and submit a qualified recommendation.`,v,[s,ing,`are ${v}`],`Jedyne rozsądne działanie, jakie nam pozostawało, to ${inf} i przedstawić rekomendację z zastrzeżeniami.`,'W rozszczepieniu All ... done was możliwy jest bezokolicznik bez to (także z to); nie stosujemy formy osobowej ani -ing.'),
 r('perfect participle negative',`Not having G ${o} ourselves, we could not vouch for the reliability of the conclusions.`,pp,[s,`to ${v}`,`have ${v}`],`Ponieważ sami ${f.negativePastPl}, nie mogliśmy ręczyć za wiarygodność wniosków.`,'Not having + imiesłów opisuje wcześniejszą niewykonaną czynność tego samego podmiotu co w zdaniu głównym.'),
 r('inversion only by',`Only by G ${o} independently could we rule out institutional bias.`,ing,[v,s,`to ${v}`],`Mogliśmy wykluczyć stronniczość instytucji tylko dlatego, że niezależnie ${past}.`,'Po przyimku by występuje -ing. Only by na początku wywołuje inwersję could we w zdaniu głównym.'),
 r('lest subjunctive',`The reviewers withheld judgment lest we G ${o} under undue pressure.`,v,[s,ing,`to ${v}`],`Recenzenci wstrzymali ocenę z obawy, że będziemy musieli ${inf} pod nadmierną presją.`,'Formalne lest wprowadza niepożądany możliwy skutek i łączy się z podstawową formą subjunctive (także z should).'),
 r('distancing perfect infinitive',`We are alleged to have G ${o} while withholding material information from the board.`,pp,[s,ing,`to ${v}`],`Zarzuca się nam, że ${past}, zatajając istotne informacje przed zarządem.`,'Are alleged dystansuje autora od twierdzenia; to have + imiesłów wskazuje zdarzenie wcześniejsze.'),
 r('unreal past perfect preference',`The chair would rather we had G ${o} before circulating the provisional conclusions.`,pp,[s,ing,`to ${v}`],`Przewodniczący wolałby, żeby udało nam się ${inf} przed rozesłaniem wstępnych wniosków.`,'Would rather + inny podmiot + Past Perfect wyraża preferencję dotyczącą zamkniętej przeszłości.'),
 r('modal perfect obligation',`We ought to have G ${o} before claiming that no further scrutiny was warranted.`,pp,[s,ing,`to ${v}`],`Powinniśmy byli najpierw ${inf}, zanim uznaliśmy dalszą kontrolę za nieuzasadnioną.`,'Ought to have + imiesłów wyraża ocenę wcześniejszego obowiązku, którego nie dopełniono.'),
 r('concessive perfect clause',`Much as we would have liked G ${o} in person, the restrictions made that impossible.`,`to ${v}`,[ing,s,`to ${ing}`],`Choć bardzo chcielibyśmy byli osobiście ${inf}, ograniczenia to uniemożliwiły.`,'Much as wprowadza formalne ustępstwo. Po would have liked używamy bezokolicznika z to.'),
 ];
}
