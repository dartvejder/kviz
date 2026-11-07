# Ispravke i brisanja posle ručne provere: (deo pitanja koji identifikuje red, nova linija ili None za brisanje)
FIX = {
 "Ko igra Mlađu": None,
 "Pop Ćiru": None,
 "Ko igra Biću": None,
 "Bobu Gajića": None,
 "porodici Popović": None,
 "prati đake u gimnaziji": None,
 "Kako se zove serija o porodici Šurdilović": "Kako se zove serija o Šurdi, koju je napisao Siniša Pavić?|Vruć vetar|Bolji život|Srećni ljudi|Kamiondžije",
 "Kako se zove kraljevstvo u filmu „Čarobnjak iz Oza”": "Iz koje američke savezne države je Doroti u „Čarobnjaku iz Oza”?|Kanzasa|Teksasa|Nebraske|Ajove",
 "Kako se zove grad u kom se odvija „Igra prestola”": "Kako se zove prestonica Sedam kraljevstava u „Igri prestola”?|Kraljeva Luka|Vinterfel|Mirin|Kasterli Rok",
 "Ko je pravo ime Spajdermena": "Kako se Spajdermen zove u stvarnom životu?|Piter Parker|Brus Vejn|Klark Kent|Toni Stark",
 "Kako se zove sneška": "Kako se zove Sneško koji voli toplo leto u filmu „Zaleđeno kraljevstvo”?|Olaf|Sven|Kristof|Hans",
}
REPL = [("Bster Kiton","Baster Kiton"),("Hortonr","Horton"),("Brad Pit","Bred Pit")]
FIX.update({
 "Ne zna se": None, "pitanje izbaciti": None,
 "Koja grupa je snimila pesmu „Beograd”": None,
 "Đurđevdan je, a ja nisam": None,
 "Kraljica narodne muzike": "Koja pevačica je bila pevačica grupe Slatki greh?|Lepa Brena|Vesna Zmijanac|Dragana Mirković|Snežana Đurišić",
 "Kako se zove grupa Šabana Šaulića": None,
})
REPL += [("Etа","Eta"),("Everli bratja","Braća Everli")]
FIX.update({
 "Koji sultan je poznat kao Sulejman Veličanstveni": "Koji sultan je osvojio Beograd 1521. godine?|Sulejman Veličanstveni|Mehmed II|Selim I|Murat III",
 "Koji vojvoda je poznat po rečima": "Koji srpski komandant je dobio čin vojvode posle Kolubarske bitke?|Živojin Mišić|Petar Bojović|Stepa Stepanović|Radomir Putnik",
 "Koji srpski naučnik je bio član Srpske akademije": None,
 "Koje godine je osnovan Beogradski univerzitet": None,
 "Ko je obnovio Pećku patrijaršiju": None,
 "Kada je Beograd postao prestonica Srbije pod knezom Milošem": "Koje godine je prestonica Srbije premeštena iz Kragujevca u Beograd?|1841.|1804.|1867.|1878.",
 "rođeno najviše rimskih careva": None,
})
REPL += [("Ksos","Erikusa"),("Teracota vojska","Terakota vojska")]
FIX.update({
 "grad na tri reke": None, "Bukovička": None,
 "Koja je najduža reka u Srbiji (cela dužina": None,
 "Koja je najduža reka koja cela protiče kroz Srbiju": None,
 "poznat po Sajmu kupusa": "U kom mestu se održava Sabor trubača?|Guči|Arilju|Ivanjici|Lučanima",
 "Sa koliko država se graniči Srbija": None,
 "Koja zemlja se ne graniči sa Srbijom": "Koja zemlja se ne graniči sa Srbijom?|Slovenija|Rumunija|Bugarska|Mađarska",
 "Koje je najveće ostrvo u Jadranskom moru": None,
 "Na kom ostrvu se nalazi Bali": None,
 "mapu svoje teritorije na zastavi": "Koja država ima mapu svoje teritorije na zastavi?|Kipar|Malta|Grčka|Liban",
 "Koja država ima zmaja na zastavi": "Koja država ima zmaja na zastavi?|Butan|Kina|Japan|Vijetnam",
 "Na kojoj planini se nalazi vrh Šiljak": "Na kojoj planini se nalazi vrh Šiljak, poznat po obliku piramide?|Rtanj|Ozren|Suva planina|Kopaonik",
})
REPL += [("Stari Glori Vels","Kraljevski barjak"),("Pola-pola tačno","Severna Amerika"),("najsevernijii","najseverniji"),
 ("Liisabonu","Lisabonu"),("se naziva „Veliku jabuku”","se naziva „Velika jabuka”"),("Kojoj državi pripada Havaji","Kojoj državi pripadaju Havaji")]
FIX.update({
 "Koja je jedina otrovna zmija": "Koje otrovne zmije žive u Srbiji?|Poskok i šarka|Smuk i belouška|Kobra i mamba|Piton i boa",
 "Ko je izumeo radio, prema patentima": None,
 "Iz koje biljke se pravi lan": None,
})
REPL += [("Galijum na 40 °C","Natrijum"),("Bar je jedina","Vat"),("Kako se zove svetlosna godina?","Šta je svetlosna godina?"),
 ("Gondvana je jedini","Atlas"),("Nakovanj je najmanji","Nakovanj"),("Klimatologija je jedina","Hidrografija"),
 ("Beli ajkula","Bela ajkula"),("Koja životinja je najveća riba na svetu?","Koja je najveća riba na svetu?"),
 ("Koja životinja je najveći gmizavac?","Koji je najveći gmizavac?"),(" (žvakaći)",""),
 ("Šta je kristal dijamant po hemijskom sastavu?","Od čega se hemijski sastoji dijamant?")]
FIX.update({
 "prvi iz Evrope odigrao više od 1000": "Koji srpski košarkaš je igrao za Los Anđeles Lejkerse od 1989. do 1996?|Vlade Divac|Žarko Paspalj|Predrag Danilović|Peja Stojaković",
 "osvojila bronzu u košarci 3x3 i zlato": None,
 "pored Đokovića, bio u finalu": "Koji srpski teniser je osvojio odlučujući meč u finalu Dejvis kupa 2010?|Viktor Troicki|Janko Tipsarević|Nenad Zimonjić|Dušan Lajović",
 "i dubl igrač je osvajao Grend slemove u dublu": "Koji srpski teniser je osvajao Grend slem titule u dublu i miks-dublu?|Nenad Zimonjić|Janko Tipsarević|Viktor Troicki|Slobodan Živojinović",
 "osvajala svetska prvenstva u skoku u dalj": "Koja srpska atletičarka je višestruka evropska prvakinja u skoku udalj?|Ivana Vuleta (Španović)|Olivera Jevtić|Dragana Tomašević|Biljana Petrović",
 "Koliko staza ima olimpijski bazen": None,
 "Kako se zove loptica sa perjem": None,
 "Koja zemlja je izmislila košarku": "U kojoj zemlji je nastala košarka?|SAD|Kanadi|Engleskoj|Francuskoj",
 "U kojoj zemlji je nastao rukomet": None,
 "Koji tim je osvojio najviše NBA titula": "Koji NBA tim ima najviše titula?|Boston Seltiks|Čikago Bulsi|Golden Stejt Voriorsi|San Antonio Sperzi",
})
REPL += [(" (2020, 2021, 2024, 2025)",""),("Koja je najbrža ženska plivačka tehnika?","Koja je najbrža plivačka tehnika?"),
 ("Maraton (i 50 km brzo hodanje ranije)","Maraton"),("Super-G je najbrži","Kombinacija"),("osvojila četiri zlata na Olimpijskim igrama 2002","osvojila tri zlata na Olimpijskim igrama 2002")]
FIX.update({
 "Žitije svetoga Save": None,
 "Piši kao što govoriš": None,
 "Koja slova su u srpskoj ćirilici nastala": None,
 "Kakvu ulogu je imao Nikola Tesla u novčanicama": "Na kojoj novčanici je lik Nikole Tesle?|100 dinara|1000 dinara|500 dinara|50 dinara",
 "čuva najveću zbirku freski": "Kako se zove beogradski muzej koji čuva kopije srpskih srednjovekovnih freski?|Galerija fresaka|Etnografski muzej|Vojni muzej|Muzej Vuka i Dositeja",
})
REPL += [("Daniel Defoe Džunior","Henri Filding"),("Koja je kulturna prestonica Evrope bio Novi Sad?","Koje godine je Novi Sad bio Evropska prestonica kulture?"),
 ("Koje godine će (ili je) Beograd ugostiti specijalizovanu izložbu Ekspo?","Koje godine Beograd organizuje specijalizovanu izložbu Ekspo?"),
 ("Tužbalica samo","Tužbalica"),("pesmu „Prolećna pesma” i „Strepnja”","pesmu „Strepnja”"),
 ("pesmu „Pesma o pevaču” i zbirku „Vatra i ništa”","zbirku „Vatra i ništa”"),("je napisao „Tajnu večeru” na zidu","je naslikao „Tajnu večeru” na zidu")]
FIX.update({
 "„gurmanska”": None, "Šta se pije uz burek": None, "bez kožice": None, "najveći proizvođač vina": None,
 "najpopularniji šah sajt": None, "sedlastu": None, "najbrojnije slovo": None, "Koliko je 1000 grama": None,
 "Koliko je mostova preko reka": None, "Prolom voda": None, "Kako se zove pečenje mesa na ražnju": None,
 "najkonzumiranija voćka": None, "potiče kroasan": None,
 "Čokoladi „Pionir”": "Iz kog grada je fabrika čokolade „Pionir”?|Subotice|Beograda|Novog Sada|Zrenjanina",
 "u Engleskoj (sličnost)": "Kako se na engleskom zove igra slična igri „Čoveče, ne ljuti se”?|Ludo|Monopol|Riziko|Šarade",
 "Koliko tima ima tim u vaterpolu na bazenu": None,
 "Koliko igrača ima tim u vaterpolu na bazenu": None,
})
REPL += [("Jodа","Joda"),("Hеlen","Helen"),("Terі","Teri"),("Soniк","Sonik"),("Koliko je kutova (uglova) ima pravougaonik?","Koliko uglova ima pravougaonik?"),("|Space","|Rudnik")]
