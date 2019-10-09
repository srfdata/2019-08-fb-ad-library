# Wahlen 2019: FB Ad Library


## Vorbemerkungen

In diesem Dokument werden einmal täglich alle Facebook-Werbeanzeigen ("Ads") Schweizer Parteien ausgewertet. Kontext: https://www.srf.ch/news/schweiz/wahlen-2019/wahlen-2019-der-facebook-wahlkampf-nimmt-fahrt-auf

**Für eine Beschreibung der Vorgehensweise siehe das Unterkapitel "Vorgehensweise" in der Datei `analysis/main.Rmd`!**

SRF Data legt Wert darauf, dass die Datenvorprozessierung und -Analyse nachvollzogen und überprüft werden kann. SRF Data glaubt an das Prinzip offener Daten, aber auch offener und nachvollziehbarer Methoden. Zum anderen soll es Dritten ermöglicht werden, auf dieser Vorarbeit aufzubauen und damit weitere Auswertungen oder Applikationen zu generieren.  

Die Endprodukte des vorliegenden Scripts, neben der vorliegenden explorativen Analyse, sind:

* `analysis/output/ads.csv`: Die verschiedenen Zeitstände von Ads inkl. der Angaben, die im Frontend der Ad Library angezeigt werden, exkl. demographischer Angaben (Datenbeschreibung siehe unten).

### R-Script & Daten

Die Vorprozessierung und Analyse wurde im Statistikprogramm R vorgenommen. Das zugrunde liegende Script sowie die prozessierten Daten können unter [diesem Link](https://srfdata.github.io/2019-08-fb-ad-library/rscript.zip) heruntergeladen werden. Durch Ausführen von `main.Rmd` kann der hier beschriebene Prozess nachvollzogen und der für den Artikel verwendete Datensatz generiert werden. Dabei werden Daten aus dem Ordner `input` eingelesen und Ergebnisse in den Ordner `output` geschrieben. 

SRF Data verwendet das [rddj-template](https://github.com/grssnbchr/rddj-template) von Timo Grossenbacher als Grundlage für seine R-Scripts.  Entstehen bei der Ausführung dieses Scripts Probleme, kann es helfen, die Anleitung von [rddj-template](https://github.com/grssnbchr/rddj-template) zu studieren. 

### GitHub

Der Code für die vorliegende Datenprozessierung ist auf [https://github.com/srfdata/2019-08-fb-ad-library](https://github.com/srfdata/2019-08-fb-ad-library) zur freien Verwendung verfügbar. 


### Lizenz

<a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/"><img alt="Creative Commons Lizenzvertrag" style="border-width:0" src="https://i.creativecommons.org/l/by-sa/4.0/88x31.png" /></a><br /><span xmlns:dct="http://purl.org/dc/terms/" href="http://purl.org/dc/dcmitype/Dataset" property="dct:title" rel="dct:type">2019-08-fb-ad-library</span> von <a xmlns:cc="http://creativecommons.org/ns#" href="https://github.com/srfdata/2019-08-fb-ad-library" property="cc:attributionName" rel="cc:attributionURL">SRF Data</a> ist lizenziert unter einer <a rel="license" href="http://creativecommons.org/licenses/by-sa/4.0/">Creative Commons Namensnennung - Weitergabe unter gleichen Bedingungen 4.0 International Lizenz</a>.

### Weitere Projekte

Code & Daten von [SRF Data](https://srf.ch/data) sind unter [https://srfdata.github.io](https://srfdata.github.io) verfügbar.

### Haftungsausschluss

Die veröffentlichten Informationen sind sorgfältig zusammengestellt, erheben aber keinen Anspruch auf Aktualität, Vollständigkeit oder Richtigkeit. Es wird keine Haftung übernommen für Schäden, die  durch die Verwendung dieses Scripts oder der daraus gezogenen Informationen entstehen. Dies gilt ebenfalls für Inhalte Dritter, die über dieses Angebot zugänglich sind.

### Datenbeschreibung

#### `output/ads.csv`

| Attribut | Typ | Beschreibung |
|-------|------|-----------------------------------------------------------------------------|
| page_name:spend.upper_bound* | mixed | Angaben, die direkt von der API übernommen werden ([Datenbeschreibung](https://www.facebook.com/ads/library/api/?source=archive-landing-page)) |
| search_expression | character  | Der initiale Suchausdruck, für den die API die Ad zurückgegeben hat (i.d.R. eine Page-ID) |
| kanton | character |  Kanton der Sektion / des/der KandidatIn, falls bekannt und zutreffend |
| region | character |  Sprachregion, falls bekannt und zutreffend (hilfreich bei nationalen Pages) |
| partei | character |  Kanonischer Parteiname, falls bekannt und zutreffend |
| account_art | character |  Art der Page: "Kantonale Sektion", "Nationale Partei", "Person" (bisherige ParlamentarierInnen) oder NA (für Resultate, die durch Freitext-Suchbegriffe erhalten wurden) |
| ad_uuid | integer |  Eindeutige ID der Ad in diesem Datensatz (Achtung: Kann sich von Tag zu Tag ändern) |
| crawl_timestamp* | character |  Zeitpunkt des Crawl-Vorgangs |

*Alle Zeitangaben sind in UTC+2 (zentraleuropäische Sommerzeit CEST).

*Inhaltlich* zeigt der Datensatz alle Zeitstände (`crawl_timestamp`) einer Ad (`ad_uuid`), bei denen die von der API gelieferten Daten *zuletzt* konsistent waren. In anderen Worten: Werden von der API andere Daten geliefert (zum Beispiel neue Angaben zu Preis und Impressions, da sich diese über die Zeit ändern können), erhält der Datensatz einen neuen Eintrag mit einem neuen `crawl_timestamp` aber der gleichen `ad_uuid`, da es sich um die gleiche Ad mit aktualisierten Informationen handelt. So lassen sich Änderungen über die Zeit nachvollziehen.


### Originalquelle

Die Originalquelle ist die [Facebook Ad Library API](https://www.facebook.com/ads/library/api/?source=archive-landing-page). Um nachzuvollziehen, wie diese täglich angefragt wird, siehe das Script im Ordner `analysis/scripts/api_bot.R`.

