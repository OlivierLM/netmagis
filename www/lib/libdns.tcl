#
# Librairie TCL pour l'application de gestion DNS.
#
#
# Historique
#   2002/03/27 : pda/jean : conception
#   2002/05/23 : pda/jean : ajout de info-groupe
#   2004/01/14 : pda/jean : ajout IPv6
#   2004/08/04 : pda/jean : ajout MAC
#   2004/08/06 : pda/jean : extension des droits sur les r�seaux
#   2006/01/26 : jean     : correction dans valide-droit-nom (cas ip EXIST)
#   2006/01/30 : jean     : message alias dans valide-droit-nom
#

package require snit			;# tcllib

##############################################################################
# Param�tres de la librairie
##############################################################################

#
# Divers formats de tabeaux
#

set libconf(tabdroits) {
    global {
	chars {10 normal}
	align {left}
	botbar {yes}
	columns {75 25}
    }
    pattern DROIT {
	vbar {yes}
	column { }
	vbar {yes}
	column { }
	vbar {yes}
    }
}

set libconf(tabdreq) {
    global {
	chars {10 normal}
	align {left}
	botbar {yes}
	columns {20 80}
    }
    pattern DroitEq {
	vbar {yes}
	column { }
	vbar {yes}
	column {
	    chars {bold}
	    format {lines}
	}
	vbar {yes}
    }
}

set libconf(tabreseaux) {
    global {
	chars {10 normal}
	align {left}
	botbar {yes}
	columns {15 35 15 35}
    }
    pattern Reseau {
	vbar {yes}
	column {
	    align {center}
	    chars {14 bold}
	    multicolumn {4}
	}
	vbar {yes}
    }
    pattern Normal4 {
	vbar {yes}
	column { }
	vbar {yes}
	column {
	    chars {bold}
	}
	vbar {yes}
	column { }
	vbar {yes}
	column {
	    chars {bold}
	}
	vbar {yes}
    }
    pattern Droits {
	vbar {yes}
	column { }
	vbar {yes}
	column {
	    multicolumn {3}
	    chars {bold}
	    format {lines}
	}
	vbar {yes}
    }
}

set libconf(tabdomaines) {
    global {
	chars {10 normal}
	align {left}
	botbar {yes}
	columns {50 25 25}
    }
    pattern Domaine {
	vbar {yes}
	column { }
	vbar {no}
	column { }
	vbar {no}
	column { }
	vbar {yes}
    }
}

set libconf(tabdhcpprofil) {
    global {
	chars {10 normal}
	align {left}
	botbar {yes}
	columns {25 75}
    }
    pattern DHCP {
	vbar {yes}
	column { }
	vbar {no}
	column {
	    format {lines}
	}
	vbar {yes}
    }
}

set libconf(tabmachine) {
    global {
	chars {10 normal}
	align {left}
	botbar {yes}
	columns {20 80}
    }
    pattern Normal {
	vbar {yes}
	column { }
	vbar {yes}
	column { }
	vbar {yes}
    }
}

set libconf(tabcorresp) {
    global {
	chars {10 normal}
	align {left}
	botbar {yes}
	columns {20 80}
    }
    pattern Normal {
	vbar {yes}
	column { }
	vbar {yes}
	column {
	    chars {gras}
	}
	vbar {yes}
    }
}

##############################################################################
# Gestion des programmes WebDNS
##############################################################################

#
# Classe d'acc�s � WebDNS
#
# Cette classe repr�sente un moyen simple pour les programmes
# (scripts CGI, d�mons ou utilitaires en ligne de commande) pour
# initier tout le contexte n�cessaire.
#
# M�thodes :
#   init-cgi
#	initialise le contexte pour un script cgi
#   init-script
#	initialise le contexte pour un programme hors cgi
#   writelog
#	affiche une ligne dans le log
#   make-url
#	cr�e une URL � partir d'un chemin et d'une liste d'arguments
#   links
#	positionne les �l�ments du bandeau recensant les liens
#
# Historique
#   2001/06/18 : pda      : conception
#   2002/12/26 : pda      : actualisation et mise en service
#   2003/05/13 : pda/jean : int�gration dans dns et utilisation de auth
#   2007/10/05 : pda/jean : adaptation aux objets "authuser" et "authbase"
#   2007/10/26 : jean     : ajout du log
#   2010/10/25 : pda      : ajout du dnsconfig
#   2010/11/05 : pda      : transformation sous forme de classe
#   2010/11/09 : pda      : ajout init-script
#

snit::type ::dnscontext {
    # database handle
    variable db ""

    # default language
    variable lang "fr"

    # log access
    variable log

    # uid
    variable uid ""
    variable euid ""
    variable eidcor -1

    # page d'erreur
    variable errorpage ""

    # parcours
    variable dnextprog ""
    variable dnextargs ""

    # liste des URL d�clar�es dans le script
    # urltab(<nom>) = {path {clef val} {clef val} {clef val...}}
    # <nom> = %[A-Z0-9]+%
    # urltab(<nom>:nextprog) = <nextprog> ou cha�ne vide
    # urltab(<nom>:nextargs) = <nextargs> (si <nextprog> != cha�ne vide)
    variable urltab -array {}

    # o� est-on dans l'application ?
    # valeurs possibles : dns topo admin
    variable curmodule	""

    # capacit�s actuelles (i.e. les droits du correspondant o� le
    # param�trage de l'application)
    # valeurs possibles : admin dns topo
    variable curcap	{}

    # liens du bandeau
    # Le tableau contient plusieurs types d'indices qui constituent une
    # structure d'arbre
    #	tab(:<module>)	{{<element>|:<module> <cap>}..{<element>|:<module> <cap>}}
    #   tab(<element>)	{<url> <lang> <desc> <lang> <desc> ...}
    #
    # Le premier type correspond � l'ordre d'affichage d'un module
    #	- un module correspond normalement � l'une des valeurs de la
    #		variable curmodule
    #	- chaque �l�ment ou module n'est affich� que si la condition
    #		mat�rialis�e par la capacit� est vraie, la capacit�
    #		fictive "always" indiquant que cet �l�ment ou module
    #		est toujours affich�
    #	- si dans la liste figure un module, celui-ci est recherch�
    #		r�cursivement (ce qui donne la structure d'arbre, les
    #		feuilles �tant les �l�ments)
    # Le deuxi�me type correspond � l'affichage de l'�l�ment du contexte

    variable links -array {
	:dns		{
			    {accueil always}
			    {consulter always}
			    {ajouter always}
			    {supprimer always}
			    {modifier always}
			    {r�lesmail always}
			    {dhcprange always}
			    {passwd always}
			    {corresp always}
			    {whereami always}
			    {topotitle topo}
			    {admtitle admin}
			}
	accueil		{%HOMEURL%/bin/accueil fr Accueil en Welcome}
	consulter	{%HOMEURL%/bin/consulter fr Consulter en Consult}
	ajouter		{%HOMEURL%/bin/ajout fr Ajouter en Add}
	supprimer	{%HOMEURL%/bin/suppr fr Supprimer en Delete}
	modifier	{%HOMEURL%/bin/modif fr Modifier en Modify}
	r�lesmail	{%HOMEURL%/bin/mail fr {R�les mail} en {Mail roles}}
	dhcprange	{%HOMEURL%/bin/dhcp fr {Plages DHCP} en {DHCP ranges}}
	passwd		{%PASSWDURL% fr {Mot de passe} en Password}
	corresp		{%HOMEURL%/bin/corr fr Rechercher en Search}
	whereami	{%HOMEURL%/bin/corresp?critere=_ fr {O� suis-je ?} en {Where am I?}}
	topotitle	{%HOMEURL%/bin/eq fr Topo en Topology}
	admtitle	{%HOMEURL%/bin/admin fr Admin en Admin}
	:topo		{
			    {eq always}
			    {l2 always}
			    {l3 always}
			    {dnstitle dns}
			    {admtitle admin}
			}
	eq		{%HOMEURL%/bin/eq fr �quipements en Equipments}
	l2		{%HOMEURL%/bin/l2 fr Vlans en Vlans}
	l3		{%HOMEURL%/bin/l3 fr R�seaux en Networks}
	dnstitle	{%HOMEURL%/bin/accueil fr DNS/DHCP en DNS/DHCP}
	:admin		{
			    {consultmx always}
			    {statcor always}
			    {statetab always}
			    {consultnet always}
			    {listecorresp always}
			    {corresp always}
			    {modetabl always}
			    {modcommu always}
			    {modhinfo always}
			    {modreseau always}
			    {moddomaine always}
			    {admrelsel always}
			    {modzone always}
			    {modzone4 always}
			    {modzone6 always}
			    {moddhcpprofil always}
			    {admgrpsel always}
			    {admgenliste always}
			    {admparliste always}
			    {dnstitle dns}
			    {topotitle topo}
			}
	consultmx	{%HOMEURL%/bin/consultmx fr {Consulter les MX} en {Consulter MX}}
	statcor		{%HOMEURL%/bin/statcor fr {Consulter les statistiques par correspondant} en {Statistics by user}}
	statetab	{%HOMEURL%/bin/statetab fr {Consulter les statistiques par �tablissement} en {Statistics by organization}}
	consultnet	{%HOMEURL%/bin/consultnet fr {Consulter les r�seaux} en {Consult networks}}
	listecorresp	{%HOMEURL%/bin/listecorresp fr {Lister les correspondants} en {List users}}
	corresp		{%HOMEURL%/bin/corresp fr {Chercher un correspondant � partir d'une adresse} en {Search}}
	modetabl	{%HOMEURL%/bin/admrefliste?type=etabl fr {Modifier les �tablissements} en {Modify organizations}}
	modcommu	{%HOMEURL%/bin/admrefliste?type=commu fr {Modifier les communaut�s} en {Modify communities}}
	modhinfo	{%HOMEURL%/bin/admrefliste?type=hinfo fr {Modifier les types de machines} en {Modify machine types}}
	modreseau	{%HOMEURL%/bin/admrefliste?type=reseau fr {Modifier les r�seaux} en {Modify networks}}
	moddomaine	{%HOMEURL%/bin/admrefliste?type=domaine fr {Modifier les domaines} en {Modify domains}}
	admrelsel	{%HOMEURL%/bin/admrelsel fr {Modifier les relais de messagerie d'un domaine} en {Modify mailhost}}
	modzone		{%HOMEURL%/bin/admrefliste?type=zone fr {Modifier les zones normales} en {Modify zones}}
	modzone4	{%HOMEURL%/bin/admrefliste?type=zone4 fr {Modifier les zones reverse IPv4} en {Modify reverse IPv4 zones}}
	modzone6	{%HOMEURL%/bin/admrefliste?type=zone6 fr {Modifier les zones reverse IPv6} en {Modify reverse IPv6 zones}}
	moddhcpprofil	{%HOMEURL%/bin/admrefliste?type=dhcpprofil fr {Modifier les profils DHCP} en {Modify DHCP profiles}}
	admgrpsel	{%HOMEURL%/bin/admgrpsel fr {Modifier les groupes et les correspondants} en {Modify users and groups}}
	admgenliste	{%HOMEURL%/bin/admgenliste fr {Forcer la g�n�ration de zones} en {Force zone generation}}
	admparliste	{%HOMEURL%/bin/admparliste fr {Modifier les param�tres de l'application} en {Application parameters}}
    }

    ###########################################################################
    # Proc�dures internes
    ###########################################################################

    #
    # Travail commun d'initialisation
    #

    proc init-common {selfns _dbfd login _tabuid} {
	global ah
	upvar $_dbfd dbfd
	upvar $_tabuid tabuid

	#
	# Acc�s � la base d'authentification
	#

	set ah [::webapp::authbase create %AUTO%]
	$ah configurelist %AUTH%

	#
	# Acc�s � la base
	#

	set dbfd [ouvrir-base %BASE% msg]
	if {$dbfd eq ""} then {
	    return "Erreur accessing database: $msg
	}
	set db $dbfd

	#
	# Initialisation du log
	#

	set log [::webapp::log create %AUTO% \
				    -subsys webdns \
				    -method opened-postgresql \
				    -medium [list "db" $dbfd table global.log] \
			]
	set uid $login
	set euid $login

	#
	# Initialisation des param�tres de configuration
	#

	config ::dnsconfig
	dnsconfig setdb $dbfd
	dnsconfig setlang "fr"

	#
	# Lire toutes les caract�ristiques du correspondant
	# et le renvoyer s'il n'est pas pr�sent.
	#

	set msg [lire-correspondant $dbfd $login tabuid]
	if {$msg ne ""} then {
	    return $msg
	}
	if {! $tabuid(present)} then {
	    return "User '$login' not authorized"
	}
	set eidcor $tabuid(idcor)

	return ""
    }

    ###########################################################################
    # Initialise l'acc�s � l'application, pour un script CGI
    #
    # Entr�e :
    #   - module : "dns", "admin" ou "topo"
    #   - pageerr : fichier HTML contenant une page d'erreur
    #   - attr : attribut n�cessaire pour ex�cuter le script (XXX : un seul attr)
    #   - form : les param�tres du formulaire
    #   - _ftab : tableau contenant en retour les champs du formulaire
    #   - _dbfd : acc�s � la base en retour
    #   - _login : login de l'utilisateur, en retour
    #   - _tabcor : tableau contenant les caract�ristiques de l'utilisateur
    #		(login, password, nom, prenom, mel, tel, fax, mobile, adr,
    #			idcor, idgrp, present)
    # Sortie :
    #   - valeur de retour : aucune
    #   - objet d : contexte DNS
    #   - objet $ah : acc�s � l'authentification
    #

    method init-cgi {module pageerr attr form _ftab _dbfd _login _tabuid} {
	upvar $_ftab ftab
	upvar $_dbfd dbfd
	upvar $_login login
	upvar $_tabuid tabuid

	#
	# Construire un contexte factice pour pouvoir retourner
	# des messages d'erreur
	#

	set login [::webapp::user]
	set uid $login
	set euid $login
	set curmodule "dns"
	set curcap {dns}
	set errorpage $pageerr

	#
	# Pour le cas o� on est en mode maintenance
	#

	set ftest %NOLOGIN%
	if {[file exists $ftest]} then {
	    if {$uid eq "" || ! ($uid in %ROOT%)} then {
		set fd [open $ftest "r"]
		set msg [read $fd]
		close $fd
		$self error $msg
	    }
	}

	#
	# Module courant
	#

	set curmodule $module

	#
	# Le login de l'utilisateur (la page est prot�g�e par mot de passe)
	#

	if {$login eq ""} then {
	    $self error "Pas de login : l'authentification a �chou�."
	}

	#
	# Travail commun d'initialisation
	#

	set msg [init-common $selfns dbfd $login tabuid]
	if {$msg ne ""} then {
	    $self error $msg
	}

	#
	# Ajouter le param�tre "uid" dans les champs de formulaire
	# et r�cup�rer les param�tres du formulaire
	#

	lappend form {uid 0 1}
	lappend form {nextprog 0 1}
	lappend form {nextargs 0 1}
	if {[llength [::webapp::get-data ftab $form]] == 0} then {
	    set msg "Formulaire non conforme aux sp�cifications"
	    if {%DEBUG%} then {
		append msg "\n$ftab(_error)"
	    }
	    $self error $msg
	}

	#
	# R�cup�rer l'�tat suivant
	#

	set dnextprog [string trim [lindex $ftab(nextprog)]]
	set dnextargs [string trim [lindex $ftab(nextargs)]]

	#
	# Traiter la substitution d'utilisateur (� travers le
	# param�tre uid)
	#

	set nuid [string trim [lindex $ftab(uid) 0]]
	if {$nuid ne "" && $tabuid(admin)} then {
	    array set tabouid [array get tabuid]
	    array unset tabuid

	    set uid $nuid
	    set login $nuid

	    set msg [lire-correspondant $dbfd $login tabuid]
	    if {$msg ne ""} then {
		$self error $msg
	    }
	    if {! $tabuid(present)} then {
		$self error "User '$login' not authorized"
	    }
	}

	#
	# D�terminer les capacit�s de l'installation locale et/ou
	# de l'utilisateur
	#

	set curcap	{}
	lappend curcap "dns"
	if {[file exists %GRAPH%]} then {
	    lappend curcap "topo"
	}
	if {$tabuid(admin)} then {
	    lappend curcap "admin"
	}

	#
	# Page accessible seulement en mode "admin" ?
	#

	if {[llength $attr] > 0} then {
	    #
	    # XXX : pour l'instant, test d'un seul attribut seulement
	    #

	    if {! [attribut-correspondant $dbfd $tabuid(idcor) $attr]} then {
		$self error "D�sol�, $login, mais vous n'avez pas les droits suffisants"
	    }
	}
    }

    ###########################################################################
    # Initialise l'acc�s � l'application, pour un programme autonome
    # (utilitaire en ligne de commande, d�mon, etc.)
    #
    # Entr�e :
    #   - _dbfd : acc�s � la base en retour
    #   - login : login de l'utilisateur
    #   - _tabuid : tableau contenant les caract�ristiques de l'utilisateur
    #		(login, password, nom, prenom, mel, tel, fax, mobile, adr,
    #			idcor, idgrp, present)
    # Sortie :
    #   - valeur de retour : message d'erreur ou cha�ne vide
    #

    method init-script {_dbfd login _tabuid} {
	upvar $_dbfd dbfd
	upvar $_tabuid tabuid

	#
	# Pour le cas o� on est en mode maintenance
	#

	if {[file exists %NOLOGIN%]} then {
	    set fd [open %NOLOGIN% "r"]
	    set message [read $fd]
	    close $fd
	    return "Connection refused.\n$message"
	}

	#
	# Travail commun d'initialisation
	#

	set msg [init-common $selfns dbfd $login tabuid]
	if {$msg ne ""} then {
	    return $msg
	}

	return ""
    }

    ###########################################################################
    # Termine l'acc�s � l'application (script CGI ou ex�cutable autonome)
    #
    # Entr�e :
    #   - aucune
    # Sortie :
    #   - valeur de retour : aucune
    #

    method end {} {
	fermer-base $db
    }

    ###########################################################################
    # R�cup�re l'�l�ment de continuation (i.e. la page � r�activer apr�s
    # la fin du "parcours" en cours)
    #
    # Entr�e : aucune
    # Sortie :
    #   - valeur de retour : <nextprog>
    #

    method nextprog {} {
	return $dnextprog
    }

    method nextargs {} {
	return $dnextargs
    }

    ###########################################################################
    # R�cup�re le login effectif du correspondant
    #
    # Entr�e : aucune
    # Sortie :
    #   - valeur de retour : liste {login idcor}
    #

    method euid {} {
	return [list $euid $eidcor]
    }

    ###########################################################################
    # Constitue une URL
    #
    # Entr�e :
    #   - path : chemin de l'URL
    #   - largs : liste {{clef val} {clef val} ...} � ajouter � l'URL
    # Sortie :
    #   - valeur de retour : URL constitu�e
    #
    # Note : chaque �l�ment {clef val} peut �galement �tre de la forme
    #	clef=val (encod�e en post-string, donc sans espace)
    #

    method make-url {path largs} {
	#
	# Ajouter les arguments "par d�faut"
	#

	if {$uid ne $euid} then {
	    lappend largs [list "uid" $uid]
	}

	#
	# Constituer la liste d'arguments
	#

	set l {}
	foreach clefval $largs {
	    if {[llength $clefval] == 1} then {
		lappend l $clefval
	    } else {
		lassign $clefval c v
		set v [::webapp::post-string $v]
		lappend l "$c=$v"
	    }
	}

	#
	# Constituer l'URL � partir du chemin et des arguments
	#

	if {[llength $l] == 0 || [regexp {^[^/]} $path]} then {
	    # pas d'argument : cas simple
	    set url $path
	} else {
	    if {[string match {*\?*} $path]} then {
		# d�j� un argument dans l'url
		set url [format "%s&%s" $path [join $l "&"]]
	    } else {
		# pas d�j� d'argument dans l'url
		set url [format "%s?%s" $path [join $l "&"]]
	    }
	}

	return $url
    }

    method urlset {name path {largs {}}} {
	lappend urllist

	set urltab($name) [linsert $largs 0 $path]
	set urltab($name:nextprog) ""
    }

    method urladd {name largs} {
	lappend url($name)
    }

    method urlsetnext {name nextprog nextargs} {
	set urltab($name:nextprog) $nextprog
	set urltab($name:nextargs) $nextargs
    }

    method urladdnext {name} {
	if {$dnextprog eq ""} then {
	    set urltab($name:nextprog) ""
	} else {
	    set urltab($name:nextprog) $dnextprog
	    set urltab($name:nextargs) $dnextargs
	}
    }

    method urlsubst {} {
	set lsubst {}
	foreach name [array names urltab] {
	    if {! [string match "*:*" $name]} then {
		set url [$self urlget $name]
		lappend lsubst [list $name $url]
	    }
	}
	return $lsubst
    }

    method urlget {name} {
	set path [lindex $urltab($name) 0]
	if {[regexp {^/} $path]} then {
	    set largs [lreplace $urltab($name) 0 0]
	    if {$urltab($name:nextprog) ne ""} then {
		lappend largs [list "nextprog" $urltab($name:nextprog)]
		lappend largs [list "nextargs" $urltab($name:nextargs)]
	    }
	    set url [$self make-url $path $largs]
	} else {
	    set url $path
	}
	unset urltab($name)
	return $url
    }


    ###########################################################################
    # Positionne le contexte servant � �tablir le bandeau de liens
    #
    # Entr�e :
    #   - module : nom de module (cf variables curmodule et links)
    # Sortie : aucune
    #

    method module {module} {
	set idx ":$module"
	if {! [info exists links($idx)]} then {
	    error "'$module' is not a valid module"
	}
	set curmodule $module
    }

    ###########################################################################
    # Renvoie une erreur et termine l'application
    # La base est ferm�e par cette fonction
    #
    # Entr�e :
    #   - msg : message d'erreur
    # Sortie :
    #   - valeur de retour : aucune (cette m�thode ne retourne pas)
    #

    method error {msg} {
	set msg [::webapp::html-string $msg]
	regsub -all "\n" $msg "<br>" msg
	$self result $errorpage [list [list %MESSAGE% $msg]]
	exit 0
    }

    ###########################################################################
    # Renvoie un r�sultat et termine l'application
    # La base est ferm�e par cette fonction
    #
    # Entr�e :
    #   - page : page HTML ou LaTeX contenant les trous
    #   - lsubst : liste de substitution pour remplir les trous
    # Sortie :
    #   - valeur de retour : aucune
    #

    method result {page lsubst} {
	#
	# D�finir le format de sortie � partir du nom de fichier
	#

	switch -glob $page {
	    *.html {
		set fmt html
	    }
	    *.tex {
		set fmt pdf
	    }
	    default {
		set fmt "unknown"
	    }
	}

	#
	# Constituer le bandeau et la liste des urls
	#
	if {$fmt eq "html"} then {

	    set bandeau [$self get-links ":$curmodule"]
	    lappend lsubst [list %BANDEAU% $bandeau]

	    foreach s [$self urlsubst] {
		lappend lsubst $s
	    }
	}

	#
	# Envoyer 
	#

	::webapp::send $fmt [::webapp::file-subst $page $lsubst]
	$self end
    }

    # proc�dure r�cursive pour r�cup�rer le bandeau de liens
    # eorm = element (without ":") or module (with ":")

    method get-links {eorm} {
	set h ""
	if {[info exists links($eorm)]} then {
	    set lks $links($eorm)

	    if {[string match ":*" $eorm]} then {
		foreach couple $lks {
		    lassign $couple neorm cond
		    if {$cond eq "always" || $cond in $curcap} then {
			append h [$self get-links $neorm]
			append h "\n"
		    }
		}
	    } else {
		set url [lindex $lks 0]
		set url [$self make-url $url {}]
		array set trans [lreplace $lks 0 0]
		set lg $lang
		if {! [info exists trans($lg)]} then {
		    set lg "fr"
		}
		append h [::webapp::helem "li" \
				[::webapp::helem "a" $trans($lg) "href" $url]]
		append h "\n"
	    }

	} else {
	    append h [::webapp::helem "li" "Unknown module '$eorm'"]
	    append h "\n"
	}
	return "$h"
    }

    ###########################################################################
    # �crire une ligne dans le syst�me de log
    # 
    # Entr�e :
    #   - param�tres :
    #	- evenement : nom de l'evenement (exemples : supprhost, suppralias etc.)
    #	- message   : message de log (par exemple les parametres de l'evenement)
    #
    # Sortie :
    #   rien
    #
    # Historique :
    #   2007/10/?? : jean : conception
    #   2010/11/09 : pda  : objet dnscontext et suppression parametre login
    #

    method writelog {evenement msg} {
	global env

	if {[info exists env(REMOTE_ADDR) ]} then {
	    set ip $env(REMOTE_ADDR)    
	} else {
	    set ip ""
	}

	$log log "" $evenement $euid $ip $msg
    }
}

##############################################################################
# Cosm�tique
##############################################################################

#
# Formatte une cha�ne de telle mani�re qu'elle apparaisse bien dans
# une case de tableau
#
# Entr�e :
#   - param�tres :
#	- string : cha�ne
# Sortie :
#   - valeur de retour : la m�me cha�ne, avec "&nbsp;" si vide
#
# Historique
#   2002/05/23 : pda     : conception
#

proc html-tab-string {string} {
    set v [::webapp::html-string $string]
    if {[string equal [string trim $v] ""]} then {
	set v "&nbsp;"
    }
    return $v
}

#
# Affiche toutes les caract�ristiques d'un correspondant dans un tableau HTML.
#
# Entr�e :
#   - param�tres :
#	- tabcor : tableau contenant les attributs du correspondant
#   - variables globales :
#	- libconf(tabcorresp) : sp�cification du tableau utilis�
# Sortie :
#   - valeur de retour : tableau html pr�t � l'emploi
#
# Historique
#   2002/07/25 : pda      : conception
#   2003/05/13 : pda/jean : utilisation de tabcor
#

proc html-correspondant {tabcorvar} {
    global libconf
    upvar $tabcorvar tabcor

    set donnees {}

    lappend donnees [list Normal Correspondant	"$tabcor(nom) $tabcor(prenom)"]
    lappend donnees [list Normal Login		$tabcor(login)]
    lappend donnees [list Normal M�l		$tabcor(mel)]
    lappend donnees [list Normal "T�l fixe"	$tabcor(tel)]
    lappend donnees [list Normal "T�l mobile"	$tabcor(mobile)]
    lappend donnees [list Normal "Fax"		$tabcor(fax)]
    lappend donnees [list Normal Localisation	$tabcor(adr)]

    return [::arrgen::output "html" $libconf(tabcorresp) $donnees]
}

##############################################################################
# Acc�s � la base
##############################################################################

#
# Initie l'acc�s � la base
#
# Entr�e :
#   - param�tres :
#	- base : informations de connexion � la base
#	- varmsg : message d'erreur lors de l'�criture, si besoin
# Sortie :
#   - valeur de retour : acc�s � la base
#
# Historique
#   2001/01/27 : pda     : conception
#   2001/10/09 : pda     : utilisation de conninfo pour acc�s via passwd
#

proc ouvrir-base {base varmsg} {
    upvar $varmsg msg
    global debug

    if {[catch {set dbfd [pg_connect -conninfo $base]} msg]} then {
	set dbfd ""
    }

    return $dbfd
}

#
# Cl�t l'acc�s � la base
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s � la base
# Sortie :
#   - valeur de retour : aucune
#
# Historique
#   2001/01/27 : pda     : conception
#

proc fermer-base {dbfd} {
    pg_disconnect $dbfd
}

##############################################################################
# Gestion des droits des correspondants
##############################################################################

#
# Proc�dure de recherche d'attribut associ� � un correspondant
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s � la base contenant les tickets
#	- idcor : correspondant
#	- attribut : attribut � v�rifier (colonne de la table pour l'instant)
# Sortie :
#   - valeur de retour : l'information trouv�e
#
# Historique
#   2000/07/26 : pda      : conception
#   2001/01/16 : pda/cty  : conception
#   2002/05/03 : pda/jean : r�cup�ration pour dns
#   2002/05/06 : pda/jean : utilisation des groupes
#

proc attribut-correspondant {dbfd idcor attribut} {
    set v 0
    set sql "SELECT groupe.$attribut \
			FROM global.groupe, global.corresp \
			WHERE corresp.idcor = $idcor \
			    AND corresp.idgrp = groupe.idgrp"
    pg_select $dbfd $sql tab {
	set v "$tab($attribut)"
    }
    return $v
}

#
# Lecture des attributs associ�s � un correspondant
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s � la base contenant les tickets
#	- login : le login du correspondant
#	- _tabuid : tableau en retour, contenant les champs
#		login	login demand�
#		idcor	id dans la base
#		idgrp	id du groupe dans la base
#		groupe	nom du groupe
#		present	1 si marqu� "pr�sent" dans la base
#		admin	1 si admin
#		reseaux	liste des r�seaux autoris�s
#		eq	regexp des �quipements autoris�s
#		flagsr	flags -n/-e/-E � utiliser dans les commandes topo
#		flagsw	flags -n/-e/-E � utiliser dans les commandes topo
# Sortie :
#   - valeur de retour : message d'erreur ou cha�ne vide
#   - param�tre tabcorvar : les attributs en retour
#
# Historique
#   2003/05/13 : pda/jean : conception
#   2007/10/05 : pda/jean : adaptation aux objets "authuser" et "authbase"
#   2010/11/09 : pda      : renommage (car plus de recherche par id)
#

proc lire-correspondant {dbfd login _tabuid} {
    global ah
    upvar $_tabuid tabuid

    catch {unset tabuid}

    #
    # Lire les caract�ristiques communes � toutes les applications
    #

    set u [::webapp::authuser create %AUTO%]
    if {[catch {set n [$ah getuser $login $u]} m]} then {
	return "Probl�me dans la base d'authentification ($m)"
    }
    
    switch $n {
	0 {
	    return "'$login' n'est pas dans la base d'authentification."
	}
	1 { 
	    # Rien
	}
	default {
	    return "Trop d'utilisateurs trouv�s"
	}
    }

    foreach c {login password nom prenom mel tel mobile fax adr} {
	set tabuid($c) [$u get $c]
    }

    $u destroy

    #
    # Lire les autres caract�ristiques, propres � cette application.
    #

    set qlogin [::pgsql::quote $login]
    set tabuid(idcor) -1
    set sql "SELECT * FROM global.corresp, global.groupe
			WHERE corresp.login = '$qlogin'
			    AND corresp.idgrp = groupe.idgrp"
    pg_select $dbfd $sql tab {
	set tabuid(idcor)	$tab(idcor)
	set tabuid(idgrp)	$tab(idgrp)
	set tabuid(present)	$tab(present)
	set tabuid(groupe)	$tab(nom)
	set tabuid(admin)	$tab(admin)
    }

    if {$tabuid(idcor) == -1} then {
	return "'$login' n'est pas dans la base des correspondants."
    }

    ######################################################################""
    # CE QUI SUIT EST SPECIFIQUE DE LA TOPO
    ######################################################################""

    #
    # Lire les CIDR des r�seaux autoris�s (fonction de la libdns)
    #

    set tabuid(reseaux) [liste-reseaux-autorises $dbfd $tabuid(idgrp) "dhcp"]

    #
    # Lire les �quipements
    #

    set tabuid(eqr) [lire-eq-autorises $dbfd 0 $tabuid(idgrp)]
    set tabuid(eqw) [lire-eq-autorises $dbfd 1 $tabuid(idgrp)]

    #
    # Construire les flags
    #

    set flagsr {}
    set flagsw {}
    foreach rw {r w} {
	set flags {}
	if {! $tabuid(admin)} then {
	    lassign $tabuid(eq$rw) lallow ldeny
	    foreach pat $lallow {
		lappend flags "-e" $pat
	    }
	    foreach pat $ldeny {
		lappend flags "-E" $pat
	    }
	    if {$rw eq "r"} then {
		foreach r $tabuid(reseaux) {
		    set r4 [lindex $r 1]
		    if {! [string equal $r4 ""]} then {
			lappend flags "-n" $r4
		    }
		    set r6 [lindex $r 2]
		    if {! [string equal $r6 ""]} then {
			lappend flags "-n" $r6
		    }
		}
	    }
	}
	set tabuid(flags$rw) [join $flags " "]
    }

    return ""
}

##############################################################################
# Gestion des RR dans la base
##############################################################################

#
# R�cup�re toutes les informations associ�es � un nom
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s la base
#	- nom : le nom � chercher
#	- iddom : le domaine
#	- tabrr : tableau vide
# Sortie :
#   - valeur de retour : 1 si ok, 0 si non trouv�
#   - param�tre tabrr : voir lire-rr-par-id
#
# Historique
#   2002/04/11 : pda/jean : conception
#   2002/04/19 : pda/jean : ajout de nom et domaine
#   2002/04/19 : pda/jean : utilisation de lire-rr-par-id
#

proc lire-rr-par-nom {dbfd nom iddom tabrr} {
    upvar $tabrr trr

    set qnom [::pgsql::quote $nom]
    set trouve 0
    set sql "SELECT idrr FROM dns.rr WHERE nom = '$qnom' AND iddom = $iddom"
    pg_select $dbfd $sql tab {
	set trouve 1
	set idrr $tab(idrr)
    }

    if {$trouve} then {
	set trouve [lire-rr-par-id $dbfd $idrr trr]
    }

    return $trouve
}

#
# R�cup�re toutes les informations associ�es au rr d'adresse IP donn�e
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s la base
#	- adr : l'adresse � chercher
#	- tabrr : tableau vide
# Sortie :
#   - valeur de retour : 1 si ok, 0 si non trouv�
#   - param�tre tabrr : voir lire-rr-par-id
#
# Note : on suppose que l'adresse fournie est syntaxiquement valide
#
# Historique
#   2002/04/26 : pda/jean : conception
#

proc lire-rr-par-ip {dbfd adr tabrr} {
    upvar $tabrr trr

    set trouve 0
    set sql "SELECT idrr FROM dns.rr_ip WHERE adr = '$adr'"
    pg_select $dbfd $sql tab {
	set trouve 1
	set idrr $tab(idrr)
    }

    if {$trouve} then {
	set trouve [lire-rr-par-id $dbfd $idrr trr]
    }

    return $trouve
}

#
# R�cup�re toutes les informations associ�es � un RR
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s la base
#	- idrr : l'id du rr � chercher
#	- tabrr : tableau vide
# Sortie :
#   - valeur de retour : 1 si ok, 0 si non trouv�
#   - param�tre tabrr :
#	tabrr(idrr) : l'id de l'objet trouv� (idrr)
#	tabrr(nom) : nom de la machine (un seul composant du fqdn)
#	tabrr(iddom) : l'id du domaine
#	tabrr(domaine) : nom du domaine
#	tabrr(mac) : l'adresse mac de la machine
#	tabrr(iddhcpprofil) : le profil DHCP sous forme d'id, ou 0
#	tabrr(dhcpprofil) : le nom du profil DHCP, ou "Aucun profil DHCP"
#	tabrr(idhinfo) : le type de machine sous forme d'id
#	tabrr(hinfo) : le type de machine sous forme de texte
#	tabrr(droitsmtp) : la machine a le droit d'�mission SMTP non authentifi�
#	tabrr(ttl) : ttl associ� � la machine (pour toutes les adresses ip)
#	tabrr(commentaire) : les infos compl�mentaires sous forme de texte
#	tabrr(respnom) : le nom+pr�nom du responsable
#	tabrr(respmel) : le m�l du responsable
#	tabrr(idcor) : l'id du correspondant ayant fait la derni�re modif
#	tabrr(date) : date de la derni�re modif
#	tabrr(ip) : les adresses IP sous forme de liste
#	tabrr(mx) : le ou les mx sous la forme {{prio idrr} {prio idrr} ...}
#	tabrr(cname) : l'id de l'objet point�, si le nom est un alias
#	tabrr(aliases) : les idrr des objets pointant vers cet objet
#	tabrr(rolemail) : l'idrr de l'h�bergeur �ventuel
#	tabrr(adrmail) : les idrr des adresses de messagerie h�berg�es
#	tabrr(roleweb) : 1 si role web pour ce rr
#
# Historique
#   2002/04/19 : pda/jean : conception
#   2002/06/02 : pda/jean : hinfo devient un index dans une table
#   2004/02/06 : pda/jean : ajout de rolemail, adrmail et roleweb
#   2004/08/05 : pda/jean : legere simplification et ajout de mac
#   2005/04/08 : pda/jean : ajout de dhcpprofil
#   2008/07/24 : pda/jean : ajout de droitsmtp
#   2010/10/31 : pda      : ajout de ttl
#

proc lire-rr-par-id {dbfd idrr tabrr} {
    upvar $tabrr trr

    set fields {nom iddom
	mac iddhcpprofil idhinfo droitsmtp ttl commentaire respnom respmel
	idcor date}

    catch {unset trr}
    set trr(idrr) $idrr

    set trouve 0
    set columns [join $fields ", "]
    set sql "SELECT $columns FROM dns.rr WHERE idrr = $idrr"
    pg_select $dbfd $sql tab {
	set trouve 1
	foreach v $fields {
	    set trr($v) $tab($v)
	}
    }

    if {$trouve} then {
	set trr(domaine) ""
	if {[string equal $trr(iddhcpprofil) ""]} then {
	    set trr(iddhcpprofil) 0
	    set trr(dhcpprofil) "Aucun profil"
	} else {
	    set sql "SELECT nom FROM dns.dhcpprofil
				WHERE iddhcpprofil = $trr(iddhcpprofil)"
	    pg_select $dbfd $sql tab {
		set trr(dhcpprofil) $tab(nom)
	    }
	}
	set sql "SELECT texte FROM dns.hinfo WHERE idhinfo = $trr(idhinfo)"
	pg_select $dbfd $sql tab {
	    set trr(hinfo) $tab(texte)
	}
	set sql "SELECT nom FROM dns.domaine WHERE iddom = $trr(iddom)"
	pg_select $dbfd $sql tab {
	    set trr(domaine) $tab(nom)
	}
	set trr(ip) {}
	pg_select $dbfd "SELECT adr FROM dns.rr_ip WHERE idrr = $idrr" tab {
	    lappend trr(ip) $tab(adr)
	}
	set trr(mx) {}
	pg_select $dbfd "SELECT priorite,mx FROM dns.rr_mx WHERE idrr = $idrr" tab {
	    lappend trr(mx) [list $tab(priorite) $tab(mx)]
	}
	set trr(cname) ""
	pg_select $dbfd "SELECT cname FROM dns.rr_cname WHERE idrr = $idrr" tab {
	    set trr(cname) $tab(cname)
	}
	set trr(aliases) {}
	pg_select $dbfd "SELECT idrr FROM dns.rr_cname WHERE cname = $idrr" tab {
	    lappend trr(aliases) $tab(idrr)
	}
	set trr(rolemail) ""
	pg_select $dbfd "SELECT heberg FROM dns.role_mail WHERE idrr = $idrr" tab {
	    set trr(rolemail) $tab(heberg)
	}
	set trr(adrmail) {}
	pg_select $dbfd "SELECT idrr FROM dns.role_mail WHERE heberg = $idrr" tab {
	    lappend trr(adrmail) $tab(idrr)
	}
	set trr(roleweb) 0
	pg_select $dbfd "SELECT 1 FROM dns.role_web WHERE idrr = $idrr" tab {
	    set trr(roleweb) 1
	}
    }

    return $trouve
}

#
# D�truit un RR �tant donn� son id
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s la base
#	- idrr : l'id du rr � d�truire
#	- msg : variable contenant en retour le message d'erreur
# Sortie :
#   - valeur de retour : 1 si ok, 0 si erreur
#   - param�tre msg : le contenu du message d'erreur si besoin
#
# Historique
#   2002/04/19 : pda/jean : conception
#

proc supprimer-rr-par-id {dbfd idrr msg} {
    upvar $msg m

    set sql "DELETE FROM dns.rr WHERE idrr = $idrr"
    return [::pgsql::execsql $dbfd $sql m]
}

#
# Supprime un alias
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s la base
#	- idrr : l'id du rr � d�truire, correspondant au nom de l'alias
#	- msg : variable contenant en retour le message d'erreur
# Sortie :
#   - valeur de retour : 1 si ok, 0 si erreur
#   - param�tre msg : le contenu du message d'erreur si besoin
#
# Historique
#   2002/04/19 : pda/jean : conception
#

proc supprimer-alias-par-id {dbfd idrr msg} {
    upvar $msg m

    set ok 0
    set sql "DELETE FROM dns.rr_cname WHERE idrr = $idrr"
    if {[::pgsql::execsql $dbfd $sql m]} then {
	if {[supprimer-rr-par-id $dbfd $idrr m]} then {
	    set ok 1
	}
    }
    return $ok
}

#
# Supprime une adresse IP
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s la base
#	- idrr : l'id du rr � d�truire
#	- adr : l'adresse IPv4 � supprimer
#	- msg : variable contenant en retour le message d'erreur
# Sortie :
#   - valeur de retour : 1 si ok, 0 si erreur
#   - param�tre msg : le contenu du message d'erreur si besoin
#
# Historique
#   2002/04/19 : pda/jean : conception
#

proc supprimer-ip-par-adresse {dbfd idrr adr msg} {
    upvar $msg m

    set ok 0
    set sql "DELETE FROM dns.rr_ip WHERE idrr = $idrr AND adr = '$adr'"
    if {[::pgsql::execsql $dbfd $sql m]} then {
	set ok 1
    }
    return $ok
}

#
# Supprime tous les MX associ�s � un RR
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s la base
#	- idrr : l'id du rr des MX � d�truire
#	- msg : variable contenant en retour le message d'erreur
# Sortie :
#   - valeur de retour : 1 si ok, 0 si erreur
#   - param�tre msg : le contenu du message d'erreur si besoin
#
# Historique
#   2002/04/19 : pda/jean : conception
#

proc supprimer-mx-par-id {dbfd idrr msg} {
    upvar $msg m

    set ok 0
    set sql "DELETE FROM dns.rr_mx WHERE idrr = $idrr"
    if {[::pgsql::execsql $dbfd $sql m]} then {
	set ok 1
    }
    return $ok
}

#
# Supprime un role mail
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s la base
#	- idrr : l'id du rr des MX � d�truire
#	- msg : variable contenant en retour le message d'erreur
# Sortie :
#   - valeur de retour : 1 si ok, 0 si erreur
#   - param�tre msg : le contenu du message d'erreur si besoin
#
# Historique
#   2004/02/06 : pda/jean : conception
#

proc supprimer-rolemail-par-id {dbfd idrr msg} {
    upvar $msg m

    set ok 0
    set sql "DELETE FROM dns.role_mail WHERE idrr = $idrr"
    if {[::pgsql::execsql $dbfd $sql m]} then {
	set ok 1
    }
    return $ok
}

#
# Supprime un role web
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s la base
#	- idrr : l'id du rr des MX � d�truire
#	- msg : variable contenant en retour le message d'erreur
# Sortie :
#   - valeur de retour : 1 si ok, 0 si erreur
#   - param�tre msg : le contenu du message d'erreur si besoin
#
# Historique
#   2004/02/06 : pda/jean : conception
#

proc supprimer-roleweb-par-id {dbfd idrr msg} {
    upvar $msg m

    set ok 0
    set sql "DELETE FROM dns.role_web WHERE idrr = $idrr"
    if {[::pgsql::execsql $dbfd $sql m]} then {
	set ok 1
    }
    return $ok
}

#
# Supprime un RR et toutes ses d�pendances
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s la base
#	- tabrr : infos du RR (cf lire-rr-par-id)
#	- msg : variable contenant en retour le message d'erreur
# Sortie :
#   - valeur de retour : 1 si ok, 0 si erreur
#   - param�tre msg : le contenu du message d'erreur si besoin
#
# Historique
#   2002/04/19 : pda/jean : conception
#   2004/02/06 : pda/jean : ajout des roles de messagerie et web
#

proc supprimer-rr-et-dependances {dbfd tabrr msg} {
    upvar $tabrr trr
    upvar $msg m

    set idrr $trr(idrr)

    #
    # S'il y a des adresses de messagerie h�berg�es, emp�cher la
    # suppression
    #

    if {[llength $trr(adrmail)] > 0} then {
	set m "Cette machine h�berge des adresses de messagerie"
	return 0
    }

    #
    # Supprimer les r�les �ventuels concernant la *machine*
    # (et non les noms qui correspondent � autre chose, comme les
    # adresses de messagerie).
    #

    if {! [supprimer-roleweb-par-id $dbfd $idrr m]} then {
	return 0
    }

    #
    # Supprimer tous les aliases pointant vers cet objet
    #

    foreach a $trr(aliases) {
	if {! [supprimer-alias-par-id $dbfd $a m]} then {
	    return 0
	}
    }

    #
    # Supprimer toutes les adresses IP
    #

    foreach a $trr(ip) {
	if {! [supprimer-ip-par-adresse $dbfd $idrr $a m]} then {
	    return 0
	}
    }

    #
    # Supprimer tous les MX
    #

    if {! [supprimer-mx-par-id $dbfd $idrr m]} then {
	return 0
    }

    #
    # Supprimer enfin le RR lui-m�me (si possible)
    #

    set m [supprimer-rr-si-orphelin $dbfd $idrr]
    if {! [string equal $m ""]} then {
	return 0
    }

    #
    # Fini !
    #

    return 1
}

#
# Supprimer un RR s'il n'y a plus rien qui pointe dessus (adresse IP,
# alias, r�le de messagerie, etc.)
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s � la base
#	- idrr : id du RR � supprimer
# Sortie :
#   - valeur de retour : cha�ne vide (ok) ou non vide (message d'erreur)
#
# Note : si le RR n'est pas orphelin, le RR n'est pas supprim� et la
#	cha�ne vide est renvoy� (c'est un cas "normal, pas une erreur).
#
# Historique
#   2004/02/13 : pda/jean : conception
#

proc supprimer-rr-si-orphelin {dbfd idrr} {
    set msg ""
    if {[lire-rr-par-id $dbfd $idrr trr]} then {
	set orphelin 1
	foreach x {ip mx aliases rolemail adrmail} {
	    if {! [string equal $trr($x) ""]} then {
		set orphelin 0
		break
	    }
	}
	if {$orphelin && $trr(roleweb)} then {
	    set orphelin 0
	}

	if {$orphelin} then {
	    if {[supprimer-rr-par-id $dbfd $trr(idrr) msg]} then {
		# �a a march�, mais la fonction a pu �ventuellement
		# modifier "msg"
		set msg ""
	    }
	}
    }
    return $msg
}

#
# Ajouter un nouveau RR
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s � la base
#	- nom : nom du RR � cr�er (la syntaxe doit �tre d�j� conforme � la RFC)
#	- iddom : id du domaine du RR
#	- mac : adresse MAC, ou vide
#	- iddhcpprofil : id du profil DHCP, ou 0
#	- idhinfo : HINFO ou cha�ne vide (le d�faut est pris dans la base)
#	- droitsmtp : 1 si droit d'�mettre en SMTP non authentifi�, ou 0
#	- ttl : valeur de ttl ou -1 pour la valeur par d�faut
#	- comment : les infos compl�mentaires sous forme de texte
#	- respnom : le nom+pr�nom du responsable
#	- respmel : le m�l du responsable
#	- idcor : l'index du correspondant
#	- tabrr : contiendra en retour les informations du RR cr��
# Sortie :
#   - valeur de retour : cha�ne vide (ok) ou non vide (message d'erreur)
#   - param�tre tabrr : voir lire-rr-par-id
#
# Attention : on suppose que la syntaxe du nom est valide. Ne pas oublier
#   d'appeler "syntaxe-nom" avant cette fonction.
#
# Historique
#   2004/02/13 : pda/jean : conception
#   2004/08/05 : pda/jean : ajout mac
#   2004/10/05 : pda      : changement du format de date
#   2005/04/08 : pda/jean : ajout dhcpprofil
#   2008/07/24 : pda/jean : ajout droitsmtp
#   2010/10/31 : pda      : ajout ttl
#

proc ajouter-rr {dbfd nom iddom mac iddhcpprofil idhinfo droitsmtp ttl
				comment respnom respmel idcor tabrr} {
    upvar $tabrr trr

    if {[string equal $mac ""]} then {
	set qmac NULL
    } else {
	set qmac "'[::pgsql::quote $mac]'"
    }
    set qcomment [::pgsql::quote $comment]
    set qrespnom [::pgsql::quote $respnom]
    set qrespmel [::pgsql::quote $respmel]
    set hinfodef ""
    set hinfoval ""
    if {! [string equal $idhinfo ""]} then {
	set hinfodef "idhinfo,"
	set hinfoval "$idhinfo, "
    }
    if {$iddhcpprofil == 0} then {
	set iddhcpprofil NULL
    }
    set sql "INSERT INTO dns.rr
		    (nom, iddom,
			mac,
			iddhcpprofil,
			$hinfodef
			droitsmtp, ttl, commentaire, respnom, respmel,
			idcor)
		VALUES
		    ('$nom', $iddom,
			$qmac,
			$iddhcpprofil,
			$hinfoval
			$droitsmtp, $ttl, '$qcomment', '$qrespnom', '$qrespmel',
			$idcor)
		    "
    if {[::pgsql::execsql $dbfd $sql msg]} then {
	set msg ""

	if {! [lire-rr-par-nom $dbfd $nom $iddom trr]} then {
	    set msg "Erreur interne : '$nom' ins�r�, mais non retrouv� dans la base"
	}
    } else {
	set msg "Cr�ation du RR impossible : $msg"
    }
    return $msg
}

#
# Met � jour la date et l'id du correspondant qui a modifi� le RR
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s � la base
#	- idrr : l'index du RR
# Sortie :
#   - valeur de retour : cha�ne vide (ok) ou non vide (message d'erreur)
#
# Historique
#   2002/05/03 : pda/jean : conception
#   2004/10/05 : pda      : changement du format de date
#   2010/11/13 : pda      : idcor = l'utilisateur effectif
#

proc touch-rr {dbfd idrr} {
    set date [clock format [clock seconds]]
    set idcor [lindex [d euid] 1]
    set sql "UPDATE dns.rr SET idcor = $idcor, date = '$date' WHERE idrr = $idrr"
    if {[::pgsql::execsql $dbfd $sql msg]} then {
       set msg ""
    } else {
	set msg "Mise � jour du RR impossible : $msg"
    }
    return $msg
}

#
# Pr�sente un RR sous forme HTML
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s la base
#	- idrr : l'id du rr � chercher ou -1 si tabrr contient d�j� tout
#	- tabrr : tableau vide (ou d�j� rempli si idrr = -1)
# Sortie :
#   - valeur de retour : cha�ne vide (erreur) ou code HTML
#   - param�tre tabrr : cf lire-rr-par-id
#   - variables globales :
#	- libconf(tabmachine) : sp�cification du tableau utilis�
#
# Historique
#   2008/07/25 : pda/jean : conception
#   2010/10/31 : pda      : ajout ttl
#

proc presenter-rr {dbfd idrr tabrr} {
    global libconf
    upvar $tabrr trr

    #
    # Lire le RR si besoin est
    #

    if {$idrr != -1 && [lire-rr-par-id $dbfd $idrr trr] == -1} then {
	return ""
    }

    #
    # Pr�senter les diff�rents champs
    #

    set donnees {}

    # nom
    lappend donnees [list Normal "Nom" "$trr(nom).$trr(domaine)"]

    # adresse(s) IP
    set at "Adresse IP"
    set aa $trr(ip)
    switch [llength $trr(ip)] {
	0 { set aa "(aucune)" }
	1 { }
	default { set at "Adresses IP" }
    }
    lappend donnees [list Normal $at $aa]

    # adresse MAC
    lappend donnees [list Normal "Adresse MAC" $trr(mac)]

    # profil DHCP
    lappend donnees [list Normal "Profil DHCP" $trr(dhcpprofil)]

    # type de machine
    lappend donnees [list Normal "Machine" $trr(hinfo)]

    # droit d'�mission SMTP : ne le pr�senter que si c'est utilis�
    # (i.e. s'il y a au moins un groupe qui a les droits)
    set sql "SELECT COUNT(*) AS ndroitsmtp FROM global.groupe WHERE droitsmtp = 1"
    set ndroitsmtp 0
    pg_select $dbfd $sql tab {
	set ndroitsmtp $tab(ndroitsmtp)
    }
    if {$ndroitsmtp > 0} then {
	if {$trr(droitsmtp)} then {
	    set droitsmtp "Oui"
	} else {
	    set droitsmtp "Non"
	}
	lappend donnees [list Normal "Droit d'�mission SMTP" $droitsmtp]
    }

    # TTL : ne le pr�senter que si c'est utilis�
    # (i.e. s'il y a au moins un groupe qui a les droits)
    # et s'il y a une valeur
    set sql "SELECT COUNT(*) AS ndroitttl FROM global.groupe WHERE droitttl = 1"
    set ndroitttl 0
    pg_select $dbfd $sql tab {
	set ndroitttl $tab(ndroitttl)
    }
    if {$ndroitttl > 0} then {
	set ttl $trr(ttl)
	if {$ttl != -1} then {
	    lappend donnees [list Normal "TTL" $ttl]
	}
    }

    # infos compl�mentaires
    lappend donnees [list Normal "Infos compl�mentaires" $trr(commentaire)]

    # responsable (nom + pr�nom)
    lappend donnees [list Normal "Responsable (nom + pr�nom)" $trr(respnom)]

    # responsable (m�l)
    lappend donnees [list Normal "Responsable (m�l)" $trr(respmel)]

    # aliases
    set la {}
    foreach idalias $trr(aliases) {
	if {[lire-rr-par-id $dbfd $idalias ta]} then {
	    lappend la "$ta(nom).$ta(domaine)"
	}
    }
    if {[llength $la] > 0} then {
	lappend donnees [list Normal "Aliases" [join $la " "]]
    }

    set html [::arrgen::output "html" $libconf(tabmachine) $donnees]
    return $html
}

##############################################################################
# V�rifications syntaxiques
##############################################################################

#
# Valide la syntaxe d'un FQDN complet au sens de la RFC 1035
# �largie pour accepter les chiffres en d�but de nom.
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s � la base
#	- fqdn : le nom � tester
#	- nomvar : contiendra en retour le nom de host
#	- domvar : contiendra en retour le domaine de host
#	- iddomvar : contiendra en retour l'id du domaine
# Sortie :
#   - valeur de retour : cha�ne vide (ok) ou non vide (message d'erreur)
#   - param�tre nom : le nom trouv�
#   - param�tre dom : le domaine trouv�
#   - param�tre iddom : l'id du domaine trouv�, ou -1 si erreur
#
# Historique
#   2004/09/21 : pda/jean : conception
#   2004/09/29 : pda/jean : ajout param�tre domvar
#

proc syntaxe-fqdn {dbfd fqdn nomvar domvar iddomvar} {
    upvar $nomvar nom
    upvar $domvar dom
    upvar $iddomvar iddom

    if {! [regexp {^([^\.]+)\.(.*)$} $fqdn bidon nom dom]} then {
	return "FQDN invalide ($fqdn)"
    }

    set msg [syntaxe-nom $nom]
    if {! [string equal $msg ""]} then {
	return $msg
    }

    set iddom [lire-domaine $dbfd $dom]
    if {$iddom < 0} then {
	return "Domaine '$dom' invalide"
    }

    return ""
}

#
# Valide la syntaxe d'un nom (partie de FQDN) au sens de la RFC 1035
# �largie pour accepter les chiffres en d�but de nom.
#
# Entr�e :
#   - param�tres :
#	- nom : le nom � tester
# Sortie :
#   - valeur de retour : cha�ne vide (ok) ou non vide (message d'erreur)
#
# Historique
#   2002/04/11 : pda/jean : conception
#

proc syntaxe-nom {nom} {
    # cas g�n�ral : une lettre-ou-chiffre en d�but, une lettre-ou-chiffre
    # � la fin (tiret interdit en fin) et lettre-ou-chiffre-ou-tiret au
    # milieu
    set re1 {[a-zA-Z0-9][-a-zA-Z0-9]*[a-zA-Z0-9]}
    # cas particulier d'une seule lettre
    set re2 {[a-zA-Z0-9]}

    if {[regexp "^$re1$" $nom] || [regexp "^$re2$" $nom]} then {
	set m ""
    } else {
	set m "Syntaxe invalide"
    }

    return $m
}



#
# Valide la syntaxe d'une adresse IPv4 ou IPv6
#
# Entr�e :
#   - param�tres :
#	- adr : l'adresse � tester
#	- type : "inet", "cidr", "loosecidr", "macaddr", "inet4", "cidr4"
# Sortie :
#   - valeur de retour : cha�ne vide (ok) ou non vide (message d'erreur)
#
# Note :
#   - le type "cidr" est strict au sens o� les bits sp�cifiant la
#	partie "machine" doivent �tre � 0 (i.e. : "1.1.1.0/24" est
#	valide, mais pas "1.1.1.1/24")
#   - le type "loosecidr" accepte les bits de machine non � 0
#
# Historique
#   2002/04/11 : pda/jean : conception
#   2002/05/06 : pda/jean : ajout du type cidr
#   2002/05/23 : pda/jean : reconnaissance des cas cidr simplifi�s (a.b/x)
#   2004/01/09 : pda/jean : ajout du cas IPv6 et simplification radicale
#   2004/10/08 : pda/jean : ajout du cas inet4
#   2004/10/20 : jean     : interdit le / pour autre chose que le type cidr
#   2008/07/22 : pda      : nouveau type loosecidr (autorise /)
#   2010/10/07 : pda      : nouveau type cidr4
#

proc syntaxe-ip {dbfd adr type} {

    switch $type {
	inet4 {
	    set cast "inet"
	    set fam  4
	}
	cidr4 {
	    set cast "cidr"
	    set type "cidr"
	    set fam  4
	}
	loosecidr {
	    set cast "inet"
	    set fam ""
	}
	default {
	    set cast $type
	    set fam ""
	}
    }
    set adr [::pgsql::quote $adr]
    set sql "SELECT $cast\('$adr'\) ;"
    set r ""
    if {[::pgsql::execsql $dbfd $sql msg]} then {
	if {! [string equal $fam ""]} then {
	    pg_select $dbfd "SELECT family ('$adr') AS fam" tab {
		if {$tab(fam) != $fam} then {
		    set r "'$adr' n'est pas une adresse IPv$fam"
		}
	    }
	}
	if {! ([string equal $type "cidr"] || [string equal $type "loosecidr"])} then {
	    if {[regexp {/}  $adr ]} then {
		set r "Le caract�re '/' est interdit dans l'adresse"
	    }
	}
    } else {
	set r "Syntaxe invalide pour '$adr'"
    }
    return $r
}

#
# Valide la syntaxe d'une adresse MAC
#
# Entr�e :
#   - param�tres :
#	- adr : l'adresse � tester
# Sortie :
#   - valeur de retour : cha�ne vide (ok) ou non vide (message d'erreur)
#
# Historique
#   2004/08/04 : pda/jean : conception
#

proc syntaxe-mac {dbfd mac} {
    return [syntaxe-ip $dbfd $mac "macaddr"]
}

#
# Valide un identificateur de profil DHCP
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s � la base
#	- iddhcpprofil : cha�ne de caract�re repr�sentant l'id, ou 0
#	- dhcpprofilvar : variable contenant en retour le nom du profil
#	- msgvar : variable contenant en retour le message d'erreur
# Sortie :
#   - valeur de retour : 1 si ok, 0 si erreur
#   - dhcpprofilvar : nom du profil trouv� dans la base (ou Aucun profil)
#   - msgvar : message d'erreur �ventuel
#
# Historique
#   2005/04/08 : pda/jean : conception
#

proc check-iddhcpprofil {dbfd iddhcpprofil dhcpprofilvar msgvar} {
    upvar $dhcpprofilvar dhcpprofil
    upvar $msgvar msg

    set msg ""

    if {! [regexp -- {^[0-9]+$} $iddhcpprofil]} then {
	set msg "Syntaxe invalide pour le profil DHCP"
    } else {
	if {$iddhcpprofil != 0} then {
	    set sql "SELECT nom FROM dns.dhcpprofil
				WHERE iddhcpprofil = $iddhcpprofil"
	    set msg "Profil DHCP invalide ($iddhcpprofil)"
	    pg_select $dbfd $sql tab {
		set dhcpprofil $tab(nom)
		set msg ""
	    }
	} else {
	    set dhcpprofil "Aucun profil"
	}
    }

    return [string equal $msg ""]
}

##############################################################################
# Validation d'un domaine
##############################################################################

#
# Cherche un nom de domaine dans la base
#
# Entr�e :
#   - param�tres :
#       - dbfd : acc�s � la base
#	- domaine : le domaine (non termin� par un ".")
# Sortie :
#   - valeur de retour : id du domaine si trouv�, -1 sinon
#
# Historique
#   2002/04/11 : pda/jean : conception
#

proc lire-domaine {dbfd domaine} {
    set domaine [::pgsql::quote $domaine]
    set iddom -1
    pg_select $dbfd "SELECT iddom FROM dns.domaine WHERE nom = '$domaine'" tab {
	set iddom $tab(iddom)
    }
    return $iddom
}

#
# Indique si le correspondant a le droit d'acc�der au domaine
#
# Entr�e :
#   - param�tres :
#       - dbfd : acc�s � la base
#	- idcor : le correspondant
#	- iddom : le domaine
#	- roles : liste des r�les � tester (noms des colonnes dans dr_dom)
# Sortie :
#   - valeur de retour : 1 si ok, 0 sinon
#
# Historique
#   2002/04/11 : pda/jean : conception
#   2002/05/06 : pda/jean : utilisation des groupes
#   2004/02/06 : pda/jean : ajout des roles
#

proc droit-correspondant-domaine {dbfd idcor iddom roles} {
    #
    # Clause pour s�lectionner les r�les demand�s
    #
    set w ""
    foreach r $roles {
	append w "AND dr_dom.$r > 0 "
    }

    set r 0
    set sql "SELECT dr_dom.iddom FROM dns.dr_dom, global.corresp
			WHERE corresp.idcor = $idcor
				AND corresp.idgrp = dr_dom.idgrp
				AND dr_dom.iddom = $iddom
				$w
				"
    pg_select $dbfd $sql tab {
	set r 1
    }
    return $r
}

#
# Indique si le correspondant a le droit d'acc�der � l'adresse IP
#
# Entr�e :
#   - param�tres :
#       - dbfd : acc�s � la base
#	- idcor : le correspondant
#	- adr : l'adresse IP
# Sortie :
#   - valeur de retour : 1 si ok, 0 sinon
#
# Historique
#   2002/04/11 : pda/jean : conception
#   2002/05/06 : pda/jean : utilisation des groupes
#   2004/01/14 : pda/jean : ajout IPv6
#

proc droit-correspondant-ip {dbfd idcor adr} {
    set r 0

    set sql "SELECT valide_ip_cor ('$adr', $idcor) AS ok"
    pg_select $dbfd $sql tab {
	if {[string equal $tab(ok) "t"]} then {
	    set r 1
	} else {
	    set r 0
	}
    }

    return $r
}

#
# Valide les droits d'un correspondant sur un nom de machine, par la
# v�rification que toutes les adresses IP lui appartiennent.
#
# Entr�e :
#   - param�tres :
#       - dbfd : acc�s � la base
#	- idcor : le correspondant
#	- tabrr : tableau des informations du RR, cf lire-rr-par-nom
# Sortie :
#   - valeur de retour : 1 si ok ou 0 si erreur
#
# Historique
#   2002/04/19 : pda/jean : conception
#

proc valide-nom-par-adresses {dbfd idcor tabrr} {
    upvar $tabrr trr

    set ok 1
    foreach ip $trr(ip) {
	if {! [droit-correspondant-ip $dbfd $idcor $ip]} then {
	    set ok 0
	    break
	}
    }

    return $ok
}

proc valide-adresses-ip {dbfd idcor idrr} {
    set ok 1
    if {[lire-rr-par-id $dbfd $idrr trr]} then {
	set ok [valide-nom-par-adresses $dbfd $idcor trr]
    }
    return $ok
}

#
# Valider que le correspondant a droit d'ajouter/modifier/supprimer le nom
# fourni suivant un certain contexte.
#
# Entr�e :
#   - param�tres :
#       - dbfd : acc�s � la base
#	- idcor : id du correspondant faisant l'action
#	- nom : nom � tester (premier composant du FQDN)
#	- domaine : domaine � tester (les n-1 derniers composants du FQDN)
#	- trr : contiendra en retour le trr (cf lire-rr-par-id)
#	- contexte : contexte dans lequel on teste le nom
# Sortie :
#   - valeur de retour : cha�ne vide (ok) ou non vide (message d'erreur)
#   - param�tre trr : contient le trr du rr trouv�, ou si le rr n'existe
#	pas, trr(idrr) = "" et trr(iddom) contient seulement l'id du domaine
#
# D�tail des tests effectu�s :
#    selon contexte
#	"machine"
#	    valide-domaine (domaine, idcor, "")
#	    si nom.domaine est ALIAS alors erreur
#	    si nom.domaine est MX alors erreur
#	    si nom.domaine est ADRMAIL
#		alors verifier-toutes-les-adresses-IP (h�bergeur, idcor)
#		      valide-domaine (domaine, idcor, "")
#	    si nom.domaine a des adresses IP
#		alors verifier-toutes-les-adresses-IP (machine, idcor)
#	    si aucun test n'est faux, alors OK
#	"machine-existante"
#	    idem "machine", mais avec un test comme quoi il y a bien
#		une adresse IP
#	"supprimer-un-nom"
#	    valide-domaine (domaine, idcor, "")
#	    si nom.domaine est ALIAS
#		alors verifier-toutes-les-adresses-IP (machine point�e, idcor)
#	    si nom.domaine est MX alors erreur
#	    si nom.domaine a des adresses IP
#		alors verifier-toutes-les-adresses-IP (machine, idcor)
#	    si nom.domaine est ADRMAIL
#		alors verifier-toutes-les-adresses-IP (h�bergeur, idcor)
#		      valide-domaine (domaine, idcor, "")
#	    si aucun test n'est faux, alors OK
#	"alias"
#	    valide-domaine (domaine, idcor, "")
#	    si nom.domaine est ALIAS alors erreur
#	    si nom.domaine est MX alors erreur
#	    si nom.domaine est ADRMAIL alors erreur
#	    si nom.domaine a des adresses IP alors erreur
#	    si aucun test n'est faux, alors OK
#	"mx"
#	    valide-domaine (domaine, idcor, "")
#	    si nom.domaine est ALIAS alors erreur
#	    si nom.domaine est MX
#		alors verifier-toutes-les-adresses-IP (�changeurs, idcor)
#	    si nom.domaine est ADRMAIL alors erreur
#	    si aucun test n'est faux, alors OK
#	"adrmail"
#	    valide-domaine (domaine, idcor, "rolemail")
#	    si nom.domaine est ALIAS alors erreur
#	    si nom.domaine est MX alors erreur
#	    si nom.domaine est ADRMAIL
#		verifier-toutes-les-adresses-IP (h�bergeur, idcor)
#		      valide-domaine (domaine, idcor, "")
#	    si nom.domaine est HEBERGEUR
#		verifier qu'il n'est pas h�bergeur pour d'autres que lui-m�me
#	    si nom.domaine a des adresses IP
#		verifier-toutes-les-adresses-IP (nom.domaine, idcor)
#	    si aucun test n'est faux, alors OK
#
#    verifier-adresses-IP (machine, idcor)
#	s'il n'y a pas d'adresse
#	    alors ERREUR
#	    sinon verifier que toutes adr IP sont dans mes plages (avec un AND)
#	fin si
#
# Historique
#   2004/02/27 : pda/jean : sp�cification
#   2004/02/27 : pda/jean : codage
#   2004/03/01 : pda/jean : remont�e du trr � la place de l'id du domaine
#

array set testsdroits {
    machine	{
		    {domaine	{}}
		    {alias	REJECT}
		    {mx		REJECT}
		    {ip		CHECK}
		    {adrmail	CHECK}
		}
    machine-existante	{
		    {domaine	{}}
		    {alias	REJECT}
		    {mx		REJECT}
		    {ip		CHECK}
		    {ip		EXISTS}
		    {adrmail	CHECK}
		}
    alias {
		    {domaine	{}}
		    {alias	REJECT}
		    {mx		REJECT}
		    {ip		REJECT}
		    {adrmail	REJECT}
		}
    supprimer-un-nom {
		    {domaine	{}}
		    {alias	CHECK}
		    {mx		REJECT}
		    {ip		CHECK}
		    {adrmail	CHECK}
		}
    mx		{
		    {domaine	{}}
		    {alias	REJECT}
		    {mx		CHECK}
		    {ip		CHECK}
		    {adrmail	REJECT}
		}
    adrmail	{
		    {domaine	rolemail}
		    {alias	REJECT}
		    {mx		REJECT}
		    {adrmail	CHECK}
		    {hebergeur	CHECK}
		    {ip		CHECK}
		}
}

proc valide-droit-nom {dbfd idcor nom domaine tabrr contexte} {
    upvar $tabrr trr
    global testsdroits

    #
    # R�cup�rer la liste des actions associ�e au contexte
    #

    if {! [info exists testsdroits($contexte)]} then {
	return "Erreur interne : contexte '$contexte' incorrect"
    }

    #
    # Encha�ner les tests dans l'ordre souhait�, et sortir
    # d�s qu'un test �choue.
    #

    set fqdn "$nom.$domaine"
    set existe 0
    foreach a $testsdroits($contexte) {
	set parm [lindex $a 1]
	switch [lindex $a 0] {
	    domaine {
		set m [valide-domaine $dbfd $idcor $domaine iddom $parm]
		if {! [string equal $m ""]} then {
		    return $m
		}

		set existe [lire-rr-par-nom $dbfd $nom $iddom trr]
		if {! $existe} then {
		    set trr(idrr) ""
		    set trr(iddom) $iddom
		}
	    }
	    alias {
		if {$existe} then {
		    set idrr $trr(cname)
		    if {! [string equal $idrr ""]} then {
			switch $parm {
			    REJECT {
				lire-rr-par-id $dbfd $idrr talias
				set alias "$talias(nom).$talias(domaine)"
				return "'$fqdn' est un alias de '$alias'"
			    }
			    CHECK {
				set ok [valide-adresses-ip $dbfd $idcor $idrr]
				if {! $ok} then {
				    return "Vous n'avez pas les droits sur '$fqdn'"
				}
			    }
			    default {
				return "Erreur interne : param�tre invalide '$parm' pour '$contexte'/$a"
			    }
			}
		    }
		}
	    }
	    mx {
		if {$existe} then {
		    set lmx $trr(mx)
		    foreach mx $lmx {
			switch $parm {
			    REJECT {
				return "'$fqdn' est un MX"
			    }
			    CHECK {
				set idrr [lindex $mx 1]
				set ok [valide-adresses-ip $dbfd $idcor $idrr]
				if {! $ok} then {
				    return "Vous n'avez pas les droits sur '$fqdn'"
				}
			    }
			    default {
				return "Erreur interne : param�tre invalide '$parm' pour '$contexte'/$a"
			    }
			}
		    }
		}
	    }
	    adrmail {
		if {$existe} then {
		    set idrr $trr(rolemail)
		    if {! [string equal $idrr ""]} then {
			switch $parm {
			    REJECT {
				return "'$fqdn' est un r�le de messagerie"
			    }
			    CHECK {
				if {! [lire-rr-par-id $dbfd $idrr trrh]} then {
				    return "Erreur interne : h�bergeur d'id '$idrr' inexistant"
				}

				#
				# V�rification des adresses IP
				#
				set ok [valide-nom-par-adresses $dbfd $idcor trrh]
				if {! $ok} then {
				    return "Vous n'avez pas les droits sur l'h�bergeur de '$fqdn'"
				}

				#
				# V�rification du domaine de l'h�bergeur
				#

				set msg [valide-domaine $dbfd $idcor $trrh(domaine) bidon ""]
				if {! [string equal $msg ""]} then {
				    return "Vous n'avez pas les droits sur l'h�bergeur de '$fqdn'\n$msg"
				}
			    }
			    default {
				return "Erreur interne : param�tre invalide '$parm' pour '$contexte'/$a"
			    }
			}
		    }
		}
	    }
	    hebergeur {
		if {$existe} then {
		    set ladr $trr(adrmail)
		    switch $parm {
			REJECT {
			    if {[llength $ladr] > 0} then {
				return "'$fqdn' est un h�bergeur pour des adresses de messagerie"
			    }
			}
			CHECK {
			    # �liminer le nom de la liste des adresses
			    # h�berg�es sur cette machine.
			    set pos [lsearch -exact $ladr $trr(idrr)]
			    if {$pos != -1} then {
				set ladr [lreplace $ladr $pos $pos]
			    }
			    if {[llength $ladr] > 0} then {
				return "'$fqdn' est un h�bergeur pour des adresses de messagerie."
			    }
			}
			default {
			    return "Erreur interne : param�tre invalide '$parm' pour '$contexte'/$a"
			}
		    }
		}
	    }
	    ip {
		if {$existe} then {
		    switch $parm {
			REJECT {
			    return "'$fqdn' a des adresses IP"
			}
			EXISTS {
			    if {[string equal $trr(ip) ""]} then {
				return "Le nom '$fqdn' ne correspond pas � une machine"
			    }
			}
			CHECK {
			    set ok [valide-nom-par-adresses $dbfd $idcor trr]
			    if {! $ok} then {
				return "Vous n'avez pas les droits sur '$fqdn'"
			    }
			}
			default {
			    return "Erreur interne : param�tre invalide '$parm' pour '$contexte'/$a"
			}
		    }
		} else {
		    if {[string equal $parm "EXISTS"]} {
			return "Le nom '$fqdn' n'existe pas"
		    }
		}
	    }
	}
    }

    return ""
}

#
# Valide les informations d'un MX telles qu'extraites d'un formulaire
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s � la base
#	- prio : priorit� lue dans le formulaire
#	- nom : nom du MX, lu dans le formulaire
#	- dom : nom de domaine du MX, lu dans le formulaire
#	- idcor : id du correspondant
#	- msgvar : param�tre pass� par variable
# Sortie :
#   - valeur de retour : liste {prio idmx} o�
#	- prio = priorit� num�rique (syntaxe enti�re ok)
#	- idmx = id d'un RR existant
#   - param�tres :
#	- msgvar : cha�ne vide si ok, ou message d'erreur
#
# Historique
#   2003/04/25 : pda/jean : conception
#   2004/03/04 : pda/jean : reprise et mise en commun
#

proc valide-mx {dbfd prio nom domaine idcor msgvar} {
    upvar $msgvar m

    #
    # Validation syntaxique de la priorit�
    #

    if {! [regexp {^[0-9]+$} $prio]} then {
	set m "Priorit� non valide ($prio)"
	return {}
    }

    #
    # Validation de l'existence du relais, du domaine, etc.
    #

    set m [valide-droit-nom $dbfd $idcor $nom $domaine trr "machine-existante"]
    if {! [string equal $m ""]} then {
	return {}
    }

    #
    # Mettre en forme le r�sultat
    #

    return [list $prio $trr(idrr)]
}

#
# Valide le domaine et l'autorisation du correspondant
#
# Entr�e :
#   - param�tres :
#       - dbfd : acc�s � la base
#	- idcor : le correspondant
#	- domaine : le domaine (en texte)
#	- iddom : contiendra en retour l'id du domaine
#	- roles : liste des r�les � tester (noms des colonnes dans dr_dom)
# Sortie :
#   - valeur de retour : cha�ne vide (ok) ou non vide (message d'erreur)
#   - param�tre iddom : l'id du domaine trouv�, ou -1 si erreur
#
# Historique
#   2002/04/11 : pda/jean : conception
#   2002/04/19 : pda/jean : ajout du param�tre iddom
#   2002/05/06 : pda/jean : utilisation des groupes
#   2004/02/06 : pda/jean : ajout des roles
#

proc valide-domaine {dbfd idcor domaine iddomvar roles} {
    upvar $iddomvar iddom

    set m ""
    set iddom [lire-domaine $dbfd $domaine]
    if {$iddom >= 0} then {
	if {[droit-correspondant-domaine $dbfd $idcor $iddom $roles]} then {
	    set m ""
	} else {
	    set m "D�sol�, mais vous n'avez pas acc�s au domaine '$domaine'"
	}
    } else {
	set m "Domaine '$domaine' inexistant"
    }
    return $m
}

#
# Valide le domaine, les relais de messagerie, par rapport au correspondant
#
# Entr�e :
#   - param�tres :
#       - dbfd : acc�s � la base
#	- idcor : le correspondant
#	- domaine : le domaine (en texte)
#	- iddom : contiendra en retour l'id du domaine
# Sortie :
#   - valeur de retour : cha�ne vide (ok) ou non vide (message d'erreur)
#   - param�tre iddom : l'id du domaine trouv�, ou -1 si erreur
#
# Historique
#   2004/03/04 : pda/jean : conception
#

proc valide-domaine-et-relais {dbfd idcor domaine iddomvar} {
    upvar $iddomvar iddom

    #
    # Valider le domaine
    #

    set msg [valide-domaine $dbfd $idcor $domaine iddom "rolemail"]
    if {! [string equal $msg ""]} then {
	return $msg
    }

    #
    # Valider que nous sommes bien propri�taire de tous les relais
    # sp�cifi�s.
    #

    set sql "SELECT r.nom AS nom, d.nom AS domaine
		FROM dns.relais_dom rd, dns.rr r, dns.domaine d
		WHERE rd.iddom = $iddom
			AND r.iddom = d.iddom
			AND rd.mx = r.idrr
		"
    pg_select $dbfd $sql tab {
	set msg [valide-droit-nom $dbfd $idcor $tab(nom) $tab(domaine) \
				trr "machine-existante"]
	if {! [string equal $msg ""]} then {
	    return "�dition refus�e pour '$domaine', car vous n'avez pas acc�s � un relais\n$msg"
	}
    }

    return ""
}

#
# Valide un r�le de messagerie.
#
# Entr�e :
#   - param�tres :
#       - dbfd : acc�s � la base
#	- idcor : le correspondant
#	- nom : nom du r�le (adresse de messagerie)
#	- domaine : domaine du r�le (adresse de messagerie)
#	- trr : contiendra en retour le trr (cf lire-rr-par-id)
#	- trrh : contiendra en retour le trr de l'h�bergeur (cf lire-rr-par-id)
# Sortie :
#   - valeur de retour : cha�ne vide (ok) ou non vide (message d'erreur)
#   - param�tre trr : contient le trr du rr trouv�, ou si le rr n'existe
#	pas, trr(idrr) = "" et trr(iddom) contient seulement l'id du domaine
#   - param�tre trrh : contient le trr du rr de l'h�bergeur,
#	si trr(rolemail) existe, ou un trr fictif contenant au moins
#	trrh(nom) et trrh(domaine)
#
# Historique
#   2004/02/12 : pda/jean : cr�ation
#   2004/02/27 : pda/jean : centralisation de la gestion des droits
#   2004/03/01 : pda/jean : ajout trr et trrh
#

proc valide-role-mail {dbfd idcor nom domaine tabrr tabrrh} {
    upvar $tabrr trr
    upvar $tabrrh trrh

    set fqdn "$nom.$domaine"

    #
    # Validation des droits
    #

    set m [valide-droit-nom $dbfd $idcor $nom $domaine trr "adrmail"]
    if {! [string equal $m ""]} then {
	return $m
    }

    #
    # R�cup�ration du rr de l'h�bergeur
    #

    catch {unset trrh}
    set trrh(nom)     ""
    set trrh(domaine) ""

    if {! [string equal $trr(idrr) ""]} then {
	set h $trr(rolemail)
	if {! [string equal $h ""]} then {
	    #
	    # Le nom fourni est une adresse de messagerie existante
	    # A-t'on le droit d'agir dessus ?
	    #
	    if {! [lire-rr-par-id $dbfd $h trrh]} then {
		return "Erreur interne sur '$fqdn' (id heberg $h non trouv�)"
	    }
	}
    }

    return ""
}

#
# Valide qu'aucune adresse IP n'empi�te sur un intervalle DHCP dynamique
# si l'adresse MAC n'est pas vide.
#
# Entr�e :
#   - param�tres :
#       - dbfd : acc�s � la base
#	- mac : l'adresse MAC (vide ou non)
#	- lip : liste des adresses IP (v4 et v6)
# Sortie :
#   - valeur de retour : cha�ne vide (ok) ou non vide (message d'erreur)
#
# Historique
#   2004/08/04 : pda/jean : conception
#

proc valide-dhcp-statique {dbfd mac lip} {
    set r ""
    if {! [string equal $mac ""]} then {
	foreach ip $lip {
	    set sql "SELECT min, max
			    FROM dns.dhcprange
			    WHERE '$ip' >= min AND '$ip' <= max"
	    pg_select $dbfd $sql tab {
		set r "Impossible d'affecter l'adresse MAC '$mac' car l'adresse IP $ip figure dans un intervalle DHCP dynamique \[$tab(min)..$tab(max)\]"
	    }
	    if {! [string equal $r ""]} then {
		break
	    }
	}
    }

    return $r
}

#
# Valide les valeurs possibles d'un TTL (au sens de la RFC 2181)
#
# Entr�e :
#   - param�tres :
#	- ttl : le ttl � valider
# Sortie :
#   - valeur de retour : cha�ne vide (ok) ou non vide (message d'erreur)
#
# Historique
#   2010/11/02 : pda/jean : conception � partir d'un code de jean
#

proc valide-ttl {ttl} {
    set r ""
    # 2^31-1
    set maxttl [expr 0x7fffffff]
    if {! [regexp {^\d+$} $ttl]} then {
	set r "TTL invalide : doit �tre un nombre entier positif"
    } else {
	if {$ttl > $maxttl} then {
	    set r "TTL invalide : doit �tre inf�rieur � $maxttl"
	}
    }
    return $r
}

##############################################################################
# Validation des correspondants
##############################################################################

#
# Valide l'acc�s d'un correspondant aux pages de l'application
#
# Entr�e :
#   - param�tres :
#       - dbfd : acc�s � la base
#	- pageerr : page d'erreur avec un trou pour le message
# Sortie :
#   - valeur de retour : id du correspondant si trouv�, pas de sortie sinon
#
# Historique
#   2002/03/27 : pda/jean : conception
#

proc valide-correspondant {dbfd pageerr} {
    #
    # Le login de l'utilisateur (la page est prot�g�e par mot de passe)
    #

    set login [::webapp::user]
    if {[string compare $login ""] == 0} then {
	d error "Pas de login : l'authentification a �chou�"
    }

    #
    # R�cup�ration des informations du correspondant
    # et validation de ses droits.
    #

    set qlogin [::pgsql::quote $login]
    set idcor -1
    set sql "SELECT idcor, present FROM global.corresp WHERE login = '$qlogin'"
    pg_select $dbfd $sql tab {
	set idcor	$tab(idcor)
	set present	$tab(present)
    }

    if {$idcor == -1} then {
	d error "D�sol�, vous n'�tes pas dans la base des correspondants."
    }
    if {! $present} then {
	d error "D�sol�, $login, mais vous n'�tes pas habilit�."
    }

    return $idcor
}


#
# Lit le groupe associ� � un correspondant
#
# Entr�e :
#   - param�tres :
#       - dbfd : acc�s � la base
#	- idcor : l'id du correspondant
# Sortie :
#   - valeur de retour : id du groupe si trouv�, ou -1
#
# Historique
#   2002/05/06 : pda/jean : conception
#

proc lire-groupe {dbfd idcor} {
    set idgrp -1
    set sql "SELECT idgrp FROM global.corresp WHERE idcor = $idcor"
    pg_select $dbfd $sql tab {
	set idgrp	$tab(idgrp)
    }
    return $idgrp
}

#
# V�rifie la syntaxe d'un nom de groupe
#
# Entr�e :
#   - param�tres :
#       - groupe : nom du groupe
# Sortie :
#   - valeur de retour : cha�ne vide (ok) ou non vide (message d'erreur)
#
# Historique
#   2008/02/13 : pda/jean : conception
#

proc syntaxe-groupe {groupe} {
    if {[regexp {^[-A-Za-z0-9]*$} $groupe]} then {
	set r ""
    } else {
	set r "Nom de groupe '$groupe' invalide (autoris�s : lettres, chiffres et caract�re moins)"
    }
    return $r
}


##############################################################################
# Validation des hinfo
##############################################################################

#
# Lit l'indice du HINFO dans la table
#
# Entr�e :
#   - dbfd : acc�s � la base
#   - texte : texte hinfo � chercher
# Sortie :
#   - valeur de retour : indice ou -1 si non trouv�
#
# Historique
#   2002/05/03 : pda/jean : conception
#

proc lire-hinfo {dbfd texte} {
    set qtexte [::pgsql::quote $texte]
    set idhinfo -1
    pg_select $dbfd "SELECT idhinfo FROM dns.hinfo WHERE texte = '$qtexte'" tab {
	set idhinfo $tab(idhinfo)
    }
    return $idhinfo
}

##############################################################################
# Validation des dhcpprofil
##############################################################################

#
# Lit l'indice du dhcpprofil dans la table
#
# Entr�e :
#   - dbfd : acc�s � la base
#   - texte : texte dhcpprofil � chercher ou ""
# Sortie :
#   - valeur de retour : indice, ou 0 si "", ou -1 si non trouv�
#
# Historique
#   2005/04/11 : pda/jean : conception
#

proc lire-dhcpprofil {dbfd texte} {
    if {[string equal $texte ""]} then {
	set iddhcpprofil 0
    } else {
	set qtexte [::pgsql::quote $texte]
	set sql "SELECT iddhcpprofil FROM dns.dhcpprofil WHERE nom = '$qtexte'"
	set iddhcpprofil -1
	pg_select $dbfd $sql tab {
	    set iddhcpprofil $tab(iddhcpprofil)
	}
    }
    return $iddhcpprofil
}

##############################################################################
# R�cup�ration d'informations pour les menus
##############################################################################

#
# R�cup�re les HINFO possibles sous forme d'un menu HTML pr�t � l'emploi
#
# Entr�e :
#   - dbfd : acc�s � la base
#   - champ : champ de formulaire (variable du CGI suivant)
#   - defval : hinfo (texte) par d�faut
# Sortie :
#   - valeur de retour : code HTML pr�t � l'emploi
#
# Historique
#   2002/05/03 : pda/jean : conception
#

proc menu-hinfo {dbfd champ defval} {
    set lhinfo {}
    set sql "SELECT texte FROM dns.hinfo \
				WHERE present = 1 \
				ORDER BY tri, texte"
    set i 0
    set defindex 0
    pg_select $dbfd $sql tab {
	lappend lhinfo [list $tab(texte) $tab(texte)]
	if {[string equal $tab(texte) $defval]} then {
	    set defindex $i
	}
	incr i
    }
    return [::webapp::form-menu $champ 1 0 $lhinfo [list $defindex]]
}

#
# R�cup�re les profils DHCP accessibles par le groupe sous forme d'un
# menu visible, ou un champ cach� si le groupe n'a acc�s � aucun profil
# DHCP.
#
# Entr�e :
#   - dbfd : acc�s � la base
#   - champ : champ de formulaire (variable du CGI suivant)
#   - idcor : identification du correspondant
#   - iddhcpprofil : identification du profil � s�lectionner (le profil
#	pr�-existant) ou 0
# Sortie :
#   - valeur de retour : liste avec deux �l�ments de code HTML pr�t � l'emploi
#	(intitul�, menu de s�lection)
#
# Historique
#   2005/04/08 : pda/jean : conception
#   2008/07/23 : pda/jean : changement format sortie
#

proc menu-dhcpprofil {dbfd champ idcor iddhcpprofil} {
    #
    # R�cup�rer les profils DHCP visibles par le groupe
    # ainsi que le profil DHCP pr�-existant
    #

    set sql "SELECT p.iddhcpprofil, p.nom
		FROM dns.dr_dhcpprofil dr, dns.dhcpprofil p, global.corresp c
		WHERE c.idcor = $idcor
		    AND dr.idgrp = c.idgrp
		    AND dr.iddhcpprofil = p.iddhcpprofil
		ORDER BY dr.tri ASC, p.nom"
    set lprof {}
    set lsel {}
    set idx 1
    pg_select $dbfd $sql tab {
	lappend lprof [list $tab(iddhcpprofil) $tab(nom)]
	if {$tab(iddhcpprofil) == $iddhcpprofil} then {
	    lappend lsel $idx
	}
	incr idx
    }

    #
    # A-t'on trouv� au moins un profil ?
    #

    if {[llength $lprof] > 0} then {
	#
	# Est-ce que le profil pr�-existant est bien dans notre
	# liste ?
	#

	if {$iddhcpprofil != 0 && [llength $lsel] == 0} then {
	    #
	    # Non. On va donc ajouter � la fin de la liste
	    # le profil pr�-existant
	    #
	    set sql "SELECT iddhcpprofil, nom
			    FROM dns.dhcpprofil
			    WHERE iddhcpprofil = $iddhcpprofil"
	    pg_select $dbfd $sql tab {
		lappend lprof [list $tab(iddhcpprofil) $tab(nom)]
		lappend lsel $idx
	    }
	}

	#
	# Ajouter le cas sp�cial en d�but de liste
	#

	set lprof [linsert $lprof 0 {0 {Aucun profil}}]

	set intitule "Profil DHCP"
	set html [::webapp::form-menu iddhcpprofil 1 0 $lprof $lsel]

    } else {
	#
	# Aucun profil trouv�. On cache l'information
	#

	set intitule ""
	set html "<INPUT TYPE=HIDDEN NAME=\"$champ\" VALUE=\"$iddhcpprofil\">"
    }

    return [list $intitule $html]
}

#
# R�cup�re le droit d'�mettre en SMTP d'une machine, ou un champ cach�
# si le groupe n'a pas acc�s � la fonctionnalit�
#
# Entr�e :
#   - dbfd : acc�s � la base
#   - champ : champ de formulaire (variable du CGI suivant)
#   - idcor : identification du correspondant
#   - droitsmtp : valeur actuelle (donc � pr�s�lectionner)
# Sortie :
#   - valeur de retour : liste avec deux �l�ments de code HTML pr�t � l'emploi
#	(intitul�, choix de s�lection)
#
# Historique
#   2008/07/23 : pda/jean : conception
#   2008/07/24 : pda/jean : utilisation de idcor plut�t que idgrp
#

proc menu-droitsmtp {dbfd champ idcor droitsmtp} {
    #
    # R�cup�rer le droit SMTP pour afficher ou non le bouton
    # d'autorisation d'�mettre en SMTP non authentifi�
    #

    set grdroitsmtp [droit-correspondant-smtp $dbfd $idcor]
    if {$grdroitsmtp} then {
	set intitule "�mettre en SMTP"
	set html [::webapp::form-bool $champ $droitsmtp]
    } else {
	set intitule ""
	set html "<INPUT TYPE=HIDDEN NAME=\"$champ\" VALUE=\"$droitsmtp\">"
    }

    return [list $intitule $html]
}

#
# R�cup�re le TTL d'une machine, ou un champ cach�
# si le groupe n'a pas acc�s � la fonctionnalit�
#
# Entr�e :
#   - dbfd : acc�s � la base
#   - champ : champ de formulaire (variable du CGI suivant)
#   - idcor : identification du correspondant
#   - ttl : valeur actuelle issue de la base
# Sortie :
#   - valeur de retour : code HTML pr�t � l'emploi
#
# Historique
#   2010/10/31 : pda      : conception
#

proc menu-ttl {dbfd champ idcor ttl} {
    #
    # Convertir la valeur de TTL issue de la base en valeur "affichable"
    #

    if {$ttl == -1} then {
	set ttl ""
    }

    #
    # R�cup�rer le droit TTL pour afficher ou non le champ de formulaire
    #

    set grdroitttl [droit-correspondant-ttl $dbfd $idcor]
    if {$grdroitttl} then {
	set intitule "TTL"
	set html [::webapp::form-text $champ 1 6 10 $ttl]
	append html " (en secondes)"
    } else {
	set intitule ""
	set html "<INPUT TYPE=HIDDEN NAME=\"$champ\" VALUE=\"$ttl\">"
    }

    return [list $intitule $html]
}


#
# Fournit le code HTML pour une s�lection de liste de domaines, soit
# sous forme de menus d�roulants si le nombre de domaines autoris�s
# est > 1, soit un texte simple avec un champ HIDDEN si = 1.
#
# Entr�e :
#   - dbfd : acc�s � la base
#   - idcor : id du correspondant
#   - champ : champ de formulaire (variable du CGI suivant)
#   - where : clause where (sans le mot-clef "where") ou cha�ne vide
#   - sel : nom du domaine � pr�-s�lectionner, ou cha�ne vide
# Sortie :
#   - valeur de retour : code HTML g�n�r�
#
# Historique :
#   2002/04/11 : pda/jean : codage
#   2002/04/23 : pda      : ajout de la priorit� d'affichage
#   2002/05/03 : pda/jean : migration en librairie
#   2002/05/06 : pda/jean : utilisation des groupes
#   2003/04/24 : pda/jean : d�composition en deux proc�dures
#   2004/02/06 : pda/jean : ajout de la clause where
#   2004/02/12 : pda/jean : ajout du param�tre sel
#   2010/11/15 : pda      : suppression param�tre pageerr
#

proc menu-domaine {dbfd idcor champ where sel} {
    set lcouples [couple-domaine-par-corresp $dbfd $idcor $where]

    set lsel [lsearch -exact $lcouples [list $sel $sel]]
    if {$lsel == -1} then {
	set lsel {}
    }

    #
    # S'il n'y a qu'un seul domaine, le pr�senter en texte, sinon
    # pr�senter tous les domaines dans un menu d�roulant
    #

    set taille [llength $lcouples]
    switch -- $taille {
	0	{
	    d error "D�sol�, mais vous n'avez aucun domaine actif"
	}
	1	{
	    set d [lindex [lindex $lcouples 0] 0]
	    set html "$d <INPUT TYPE=\"HIDDEN\" NAME=\"$champ\" VALUE=\"$d\">"
	}
	default	{
	    set html [::webapp::form-menu $champ 1 0 $lcouples $lsel]
	}
    }

    return $html
}

#
# Retourne une liste de couples {nom nom} pour chaque domaine
# autoris� pour le correspondant.
#
# Entr�e :
#   - dbfd : acc�s � la base
#   - idcor : id du correspondant
#   - where : clause where (sans le mot-clef "where") ou cha�ne vide
# Sortie :
#   - valeur de retour : liste de couples
#
# Historique :
#   2003/04/24 : pda/jean : codage
#   2004/02/06 : pda/jean : ajout de la clause where
#

proc couple-domaine-par-corresp {dbfd idcor where} {
    #
    # R�cup�ration des domaines auxquels le correspond a acc�s
    # et construction d'une liste {{domaine domaine}} pour l'appel
    # ult�rieur � "form-menu"
    #

    if {! [string equal $where ""]} then {
	set where " AND $where"
    }

    set lcouples {}
    set sql "SELECT domaine.nom
		FROM dns.domaine, dns.dr_dom, global.corresp
		WHERE domaine.iddom = dr_dom.iddom
		    AND dr_dom.idgrp = corresp.idgrp
		    AND corresp.idcor = $idcor
		    $where
		ORDER BY dr_dom.tri ASC"
    pg_select $dbfd $sql tab {
	lappend lcouples [list $tab(nom) $tab(nom)]
    }

    return $lcouples
}

##############################################################################
# R�cup�ration des informations associ�es � un groupe
##############################################################################

#
# R�cup�re la liste des groupes
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s � la base
#	- n : 1 s'il faut une liste � 1 �l�ment, 2 s'il en faut 2, etc.
# Sortie :
#   - valeur de retour : liste des noms (ou des {noms noms}) des groupes
#
# Historique
#   2006/02/17 : pda/jean/zamboni : cr�ation
#   2007/10/10 : pda/jean         : ignorer le groupe des orphelins
#

proc liste-groupes {dbfd {n 1}} {
    set l {}
    for {set i 0} {$i < $n} {incr i} {
	lappend l "nom"
    }
    return [::pgsql::getcols $dbfd global.groupe "nom <> ''" "nom ASC" $l]
}

#
# Fournit du code HTML pour chaque groupe d'informations associ� � un
# groupe : les droits g�n�raux du groupe, les correspondants, les
# r�seaux, les droits hors r�seaux, les domaines, les profils DHCP
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s � la base
#	- idgrp : identificateur du groupe
#   - variable globale libconf(tabreseaux) : sp�c. de tableau
#   - variable globale libconf(tabdomaines) : sp�c. de tableau
# Sortie :
#   - valeur de retour : liste � 7 �l�ments, chaque �l�ment �tant
#	le code HTML associ�.
#
# Historique
#   2002/05/23 : pda/jean : sp�cification et conception
#   2005/04/06 : pda      : ajout des profils dhcp
#   2007/10/23 : pda/jean : ajout des correspondants
#   2008/07/23 : pda/jean : ajout des droits du groupe
#   2010/10/31 : pda      : ajout des droits ttl
#   2010/11/03 : pda/jean : ajout des droits sur les �quipements
#

proc info-groupe {dbfd idgrp} {
    global libconf

    #
    # R�cup�ration des droits particuliers : admin, droitsmtp et droitttl
    #

    set donnees {}
    set sql "SELECT admin, droitsmtp, droitttl
			FROM global.groupe
			WHERE idgrp = $idgrp"
    pg_select $dbfd $sql tab {
	if {$tab(admin)} then {
	    set admin "oui"
	} else {
	    set admin "non"
	}
	if {$tab(droitsmtp)} then {
	    set droitsmtp "oui"
	} else {
	    set droitsmtp "non"
	}
	if {$tab(droitttl)} then {
	    set droitttl "oui"
	} else {
	    set droitttl "non"
	}
	lappend donnees [list DROIT "Administration de l'application" $admin]
	lappend donnees [list DROIT "Gestion des �metteurs SMTP" $droitsmtp]
	lappend donnees [list DROIT "�dition des TTL" $droitttl]
    }
    if {[llength $donnees] > 0} then {
	set tabdroits [::arrgen::output "html" $libconf(tabdroits) $donnees]
    } else {
	set tabdroits "Erreur sur les droits du groupe"
    }

    #
    # R�cup�ration des correspondants
    #

    set lcor {}
    set sql "SELECT login FROM global.corresp WHERE idgrp=$idgrp ORDER BY login"
    pg_select $dbfd $sql tab {
	lappend lcor [::webapp::html-string $tab(login)]
    }
    set tabcorresp [join $lcor ", "]

    #
    # R�cup�ration des plages auxquelles a droit le correspondant
    #

    set donnees {}
    set sql "SELECT r.idreseau,
			r.nom, r.localisation, r.adr4, r.adr6,
			d.dhcp, d.acl,
			e.nom AS etabl,
			c.nom AS commu
		FROM dns.reseau r, dns.dr_reseau d, dns.etablissement e, dns.communaute c
		WHERE d.idgrp = $idgrp
			AND d.idreseau = r.idreseau
			AND e.idetabl = r.idetabl
			AND c.idcommu = r.idcommu
		ORDER BY d.tri, r.adr4, r.adr6"
    pg_select $dbfd $sql tab {
	set r_nom 	[::webapp::html-string $tab(nom)]
	set r_loc	[::webapp::html-string $tab(localisation)]
	set r_etabl	$tab(etabl)
	set r_commu	$tab(commu)
	set r_dhcp	$tab(dhcp)
	set r_acl	$tab(acl)

	# affadr : utilis� pour l'affichage cosm�tique des adresses
	set affadr {}
	# where : partie de la clause WHERE pour la s�lection des adresses
	set where  {}
	foreach a {adr4 adr6} {
	    if {! [string equal $tab($a) ""]} then {
		lappend affadr $tab($a)
		lappend where  "adr <<= '$tab($a)'"
	    }
	}
	set affadr [join $affadr ", "]
	set where  [join $where  " OR "]

	lappend donnees [list Reseau $r_nom]
	lappend donnees [list Normal4 Localisation $r_loc \
				�tablissement $r_etabl]
	lappend donnees [list Normal4 Plage $affadr \
				Communaut� $r_commu]

	set droits {}

	set dres {}
	if {$r_dhcp} then { lappend dres "dhcp" }
	if {$r_acl} then { lappend dres "acl" }
	if {[llength $dres] > 0} then {
	    lappend droits [join $dres ", "]
	}
	set sql2 "SELECT adr, allow_deny
			FROM dns.dr_ip
			WHERE ($where)
			    AND idgrp = $idgrp
			ORDER BY adr"
	pg_select $dbfd $sql2 tab2 {
	    if {$tab2(allow_deny)} then {
		set x "+"
	    } else {
		set x "-"
	    }
	    lappend droits "$x $tab2(adr)"
	}

	lappend donnees [list Droits Droits [join $droits "\n"]]
    }

    if {[llength $donnees] > 0} then {
	set tabreseaux [::arrgen::output "html" $libconf(tabreseaux) $donnees]
    } else {
	set tabreseaux "Aucun r�seau autoris�"
    }

    #
    # S�lectionner les droits hors des plages r�seaux identifi�es
    # ci-dessus.
    #

    set donnees {}
    set trouve 0
    set sql "SELECT adr, allow_deny
		    FROM dns.dr_ip
		    WHERE NOT (adr <<= ANY (
				SELECT r.adr4
					FROM dns.reseau r, dns.dr_reseau d
					WHERE r.idreseau = d.idreseau
						AND d.idgrp = $idgrp
				UNION
				SELECT r.adr6
					FROM dns.reseau r, dns.dr_reseau d
					WHERE r.idreseau = d.idreseau
						AND d.idgrp = $idgrp
				    ) )
			AND idgrp = $idgrp
		    ORDER BY adr"
    set droits {}
    pg_select $dbfd $sql tab {
	set trouve 1
	if {$tab(allow_deny)} then {
	    set x "+"
	} else {
	    set x "-"
	}
	lappend droits "$x $tab(adr)"
    }
    lappend donnees [list Droits Droits [join $droits "\n"]]

    if {$trouve} then {
	set tabcidrhorsreseau [::arrgen::output "html" \
						$libconf(tabreseaux) $donnees]
    } else {
	set tabcidrhorsreseau "Aucun (tout va bien)"
    }


    #
    # S�lectionner les domaines
    #

    set donnees {}
    set sql "SELECT domaine.nom AS nom, dr_dom.rolemail, dr_dom.roleweb \
			FROM dns.dr_dom, dns.domaine
			WHERE dr_dom.iddom = domaine.iddom \
				AND dr_dom.idgrp = $idgrp \
			ORDER BY dr_dom.tri, domaine.nom"
    pg_select $dbfd $sql tab {
	set rm ""
	if {$tab(rolemail)} then {
	    set rm "�dition des r�les de messagerie"
	}
	set rw ""
	if {$tab(roleweb)} then {
	    set rw "�dition des r�les web"
	}

	lappend donnees [list Domaine $tab(nom) $rm $rw]
    }
    if {[llength $donnees] > 0} then {
	set tabdomaines [::arrgen::output "html" $libconf(tabdomaines) $donnees]
    } else {
	set tabdomaines "Aucun domaine autoris�"
    }

    #
    # S�lectionner les profils DHCP
    #

    set donnees {}
    set sql "SELECT p.nom, dr.tri, p.texte
			FROM dns.dhcpprofil p, dns.dr_dhcpprofil dr
			WHERE p.iddhcpprofil = dr.iddhcpprofil
				AND dr.idgrp = $idgrp
			ORDER BY dr.tri, p.nom"
    pg_select $dbfd $sql tab {
	lappend donnees [list DHCP $tab(nom) $tab(texte)]
    }
    if {[llength $donnees] > 0} then {
	set tabdhcpprofil [::arrgen::output "html" $libconf(tabdhcpprofil) $donnees]
    } else {
	set tabdhcpprofil "Aucun profil DHCP autoris�"
    }

    #
    # S�lectionner les droits sur les �quipements
    #

    set donnees {}
    foreach {rw text} {0 Lecture 1 Modification} {
	set sql "SELECT allow_deny, pattern
			    FROM topo.dr_eq
			    WHERE idgrp = $idgrp AND rw = $rw
			    ORDER BY rw, allow_deny DESC, pattern"
	set dr ""
	pg_select $dbfd $sql tab {
	    if {$tab(allow_deny) eq "0"} then {
		set allow_deny "-"
	    } else {
		set allow_deny "+"
	    }
	    append dr "$allow_deny $tab(pattern)\n"
	}
	if {$dr eq ""} then {
	    set dr "Aucun droit"
	}
	lappend donnees [list DroitEq $text $dr]
    }
    set tabdreq [::arrgen::output "html" $libconf(tabdreq) $donnees]

    #
    # Renvoyer les informations
    #

    return [list    $tabdroits \
		    $tabcorresp \
		    $tabreseaux \
		    $tabcidrhorsreseau \
		    $tabdomaines \
		    $tabdhcpprofil \
		    $tabdreq \
	    ]
}

#
# Fournit la liste des r�seaux associ�s � un groupe avec un certain droit.
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s � la base
#	- idgrp : identificateur du groupe
#	- droit : "consult", "dhcp" ou "acl"
# Sortie :
#   - valeur de retour : liste des r�seaux sous la forme
#		{idreseau cidr4 cidr6 nom-complet}
#
# Historique
#   2004/01/16 : pda/jean : sp�cification et conception
#   2004/08/06 : pda/jean : extension des droits sur les r�seaux
#   2004/10/05 : pda/jean : adaptation aux nouveaux droits
#   2006/05/24 : pda/jean/boggia : s�paration en une fonction �l�mentaire
#

proc liste-reseaux-autorises {dbfd idgrp droit} {
    #
    # Mettre en forme les droits pour la clause where
    #

    switch -- $droit {
	consult {
	    set w1 ""
	    set w2 ""
	}
	dhcp {
	    set w1 "AND d.$droit > 0"
	    set w2 "AND r.$droit > 0"
	}
	acl {
	    set w1 "AND d.$droit > 0"
	    set w2 ""
	}
    }

    #
    # R�cup�rer tous les r�seaux autoris�s par le groupe selon ce droit
    #

    set lres {}
    set sql "SELECT r.idreseau, r.nom, r.adr4, r.adr6
			FROM dns.reseau r, dns.dr_reseau d
			WHERE r.idreseau = d.idreseau
			    AND d.idgrp = $idgrp
			    $w1 $w2
			ORDER BY adr4, adr6"
    pg_select $dbfd $sql tab {
	lappend lres [list $tab(idreseau) $tab(adr4) $tab(adr6) $tab(nom)]
    }

    return $lres
}

#
# Fournit la liste de r�seaux associ�s � un groupe avec un certain droit,
# pr�te � �tre utilis�e dans un menu.
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s � la base
#	- idgrp : identificateur du groupe
#	- droit : "consult", "dhcp" ou "acl"
# Sortie :
#   - valeur de retour : liste des r�seaux sous la forme {idreseau nom-complet}
#
# Historique
#   2006/05/24 : pda/jean/boggia : s�paration du coeur de la fonction
#

proc liste-reseaux {dbfd idgrp droit} {
    #
    # Pr�sente la liste �l�mentaire retourn�e par liste-reseaux-autorises
    #

    set lres {}
    foreach r [liste-reseaux-autorises $dbfd $idgrp $droit] {
	lappend lres [list [lindex $r 0] \
			[format "%s\t%s\t(%s)" \
				[lindex $r 1] \
				[lindex $r 2] \
				[::webapp::html-string [lindex $r 3]] \
			    ] \
			]
    }

    return $lres
}

#
# Valide un idreseau tel que retourn� par un formulaire. Cette validation
# est r�alis� dans le contexte d'un groupe, avec test d'un droit particulier.
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s � la base
#	- idreseau : id � v�rifier
#	- idgrp : identificateur du groupe
#	- droit : "consult", "dhcp" ou "acl"
#	- version : 4, 6 ou {4 6}
#	- msgvar : message d'erreur en retour
# Sortie :
#   - valeur de retour : liste de CIDR, ou liste vide
#   - param�tre msgvar : message d'erreur en retour si liste vide
#
# Historique
#   2004/10/05 : pda/jean : sp�cification et conception
#

proc valide-idreseau {dbfd idreseau idgrp droit version msgvar} {
    upvar $msgvar msg

    #
    # Valider le num�ro de r�seau au niveau syntaxique
    #
    set idreseau [string trim $idreseau]
    if {! [regexp {^[0-9]+$} $idreseau]} then {
	set msg "Plage r�seau invalide ($idreseau)"
	return {}
    }

    #
    # Convertir le droit en clause where
    #

    switch -- $droit {
	consult {
	    set w1 ""
	    set w2 ""
	    set c "en consultation"
	}
	dhcp {
	    set w1 "AND d.$droit > 0"
	    set w2 "AND r.$droit > 0"
	    set c "pour le droit '$droit'"
	}
	acl {
	    set w1 "AND d.$droit > 0"
	    set w2 ""
	    set c "pour le droit '$droit'"
	}
    }

    #
    # Valider le num�ro de r�seau et r�cup�rer le ou les CIDR associ�(s)
    #

    set lcidr {}
    set msg ""

    set sql "SELECT r.adr4, r.adr6
		    FROM dns.dr_reseau d, dns.reseau r
		    WHERE d.idgrp = $idgrp
			AND d.idreseau = r.idreseau
			AND r.idreseau = $idreseau
			$w1 $w2"
    set cidrplage4 ""
    set cidrplage6 ""
    pg_select $dbfd $sql tab {
	set cidrplage4 $tab(adr4)
	set cidrplage6 $tab(adr6)
    }

    if {[lsearch -exact $version 4] == -1} then {
	set cidrplage4 ""
    }
    if {[lsearch -exact $version 6] == -1} then {
	set cidrplage6 ""
    }

    set vide4 [string equal $cidrplage4 ""]
    set vide6 [string equal $cidrplage6 ""]

    switch -glob $vide4-$vide6 {
	1-1 {
	    set msg "Vous n'avez pas acc�s � ce r�seau $c"
	}
	0-1 {
	    lappend lcidr $cidrplage4
	}
	1-0 {
	    lappend lcidr $cidrplage6
	}
	0-0 {
	    lappend lcidr $cidrplage4
	    lappend lcidr $cidrplage6
	}
    }

    return $lcidr
}

#
# Indique si le groupe du correspondant a le droit d'autoriser des
# �metteurs SMTP.
#
# Entr�e :
#   - param�tres :
#       - dbfd : acc�s � la base
#	- idcor : le correspondant
# Sortie :
#   - valeur de retour : 1 si ok, 0 sinon
#
# Historique
#   2008/07/23 : pda/jean : conception
#   2008/07/24 : pda/jean : changement de idgrp en idcor
#

proc droit-correspondant-smtp {dbfd idcor} {
    set sql "SELECT droitsmtp FROM global.groupe g, global.corresp c 
				WHERE g.idgrp = c.idgrp AND c.idcor = $idcor"
    set r 0
    pg_select $dbfd $sql tab {
	set r $tab(droitsmtp)
    }
    return $r
}

#
# Indique si le groupe du correspondant a le droit d'�diter les TTL
#
# Entr�e :
#   - param�tres :
#       - dbfd : acc�s � la base
#	- idcor : le correspondant
# Sortie :
#   - valeur de retour : 1 si ok, 0 sinon
#
# Historique
#   2010/10/31 : pda/jean : conception
#

proc droit-correspondant-ttl {dbfd idcor} {
    set sql "SELECT droitttl FROM global.groupe g, global.corresp c 
				WHERE g.idgrp = c.idgrp AND c.idcor = $idcor"
    set r 0
    pg_select $dbfd $sql tab {
	set r $tab(droitttl)
    }
    return $r
}


##############################################################################
# Edition de valeurs de tableau
##############################################################################

#
# Pr�sente le contenu d'une table pour �dition des valeurs qui s'y trouvent
#
# Entr�e :
#   - param�tres :
#	- largeurs : largeurs des colonnes pour la sp�cification du tableau
#		au format {largeur1 largeur2 ... largeurn} (en %)
#	- titre : sp�cification des titres (format et valeur)
#		au format {type valeur} o� type = texte ou html
#	- spec : sp�cification des lignes normales
#		au format {id type defval} o�
#			- id : identificateur de la colonne dans la table
#				et nom du champ de formulaire (idNNN ou idnNNN)
#			- type : texte, string N, bool, menu L, textarea L H
#			- defval : valeur par d�faut pour les nouvelles lignes
#	- dbfd : acc�s � la base
#	- sql : requ�te select contenant en particulier les champs "id"
#	- idnum : nom de la colonne repr�sentant l'identificateur num�rique
#	- tabvar : tableau pass� par variable, vide en entr�e
# Sortie :
#   - valeur de retour : cha�ne vide si ok, message d'erreur si pb
#   - param�tre tabvar : un tableau HTML complet
#
# Historique
#   2001/11/01 : pda      : sp�cification et documentation
#   2001/11/01 : pda      : codage
#   2002/05/03 : pda/jean : type menu
#   2002/05/06 : pda/jean : type textarea
#   2002/05/16 : pda      : conversion � arrgen
#

proc edition-tableau {largeurs titre spec dbfd sql idnum tabvar} {
    upvar $tabvar tab

    #
    # Petit test d'int�grit� sur le nombre de colonnes (doit �tre
    # identique dans les largeurs, dans les titres et dans les
    # lignes normales
    #

    if {[llength $titre] != [llength $spec] || \
	[llength $titre] != [llength $largeurs]} then {
	return "Interne (edition-tableau): Sp�cification de tableau invalide"
    }

    #
    # Construire la sp�cification du tableau : comme c'est fastidieux,
    # on l'a mis dans une proc�dure � part.
    #

    set spectableau [edition-tableau-motif $largeurs $titre $spec]
    set donnees {}

    #
    # Sortir le titre
    #

    set ligne {}
    lappend ligne Titre
    foreach t $titre {
	lappend ligne [lindex $t 1]
    }
    lappend donnees $ligne

    #
    # Sortir les lignes du tableau
    #

    pg_select $dbfd $sql tabsql {
	lappend donnees [edition-ligne $spec tabsql $idnum]
    }

    #
    # Ajouter de nouvelles lignes
    #

    foreach s $spec {
	set clef [lindex $s 0]
	set defval [lindex $s 2]
	set tabdef($clef) $defval
    }

    for {set i 1} {$i <= 5} {incr i} {
	set tabdef($idnum) "n$i"
	lappend donnees [edition-ligne $spec tabdef $idnum]
    }

    #
    # Transformer le tout en joli tableau
    #

    set tab [::arrgen::output "html" $spectableau $donnees]

    #
    # Tout s'est bien pass� !
    #

    return ""
}

#
# Construit une sp�cification de tableau pour arrgen � partir des
# param�tres pass�s � edition-tableau
#
# Entr�e :
#   - param�tres :
#	- largeurs : largeurs des colonnes pour la sp�cification du tableau
#	- titre : sp�cification des titres (format et valeur)
#	- spec : sp�cification des lignes normales
# Sortie :
#   - valeur de retour : une sp�cification de tableau pr�te pour arrgen
#
# Note : voir la signification des param�tres dans edition-tableau
#
# Historique
#   2001/11/01 : pda : conception et documentation
#   2002/05/16 : pda : conversion � arrgen
#

proc edition-tableau-motif {largeurs titre spec} {
    #
    # Construire le motif des titres d'abord
    #
    set motif_titre "motif {Titre} {"
    foreach t $titre {
	append motif_titre "vbar {yes} "
	append motif_titre "chars {bold} "
	append motif_titre "align {center} "
	append motif_titre "column { "
	append motif_titre "  botbar {yes} "
	if {[string compare [lindex $t 0] "texte"] != 0} then {
	    append motif_titre "  format {raw} "
	}
	append motif_titre "} "
    }
    append motif_titre "vbar {yes} "
    append motif_titre "} "

    #
    # Ensuite, les lignes normales
    #
    set motif_normal "motif {Normal} {"
    foreach t $spec {
	append motif_normal "topbar {yes} "
	append motif_normal "vbar {yes} "
	append motif_normal "column { "
	append motif_normal "  align {center} "
	append motif_normal "  botbar {yes} "
	set type [lindex [lindex $t 1] 0]
	if {[string compare $type "texte"] != 0} then {
	    append motif_normal "  format {raw} "
	}
	append motif_normal "} "
    }
    append motif_normal "vbar {yes} "
    append motif_normal "} "

    #
    # Et enfin les sp�cifications globales
    #
    set spectableau "global { chars {12 normal} "
    append spectableau "columns {$largeurs} } $motif_titre $motif_normal"

    return $spectableau
}

#
# Pr�sente le contenu d'une ligne d'une table
#
# Entr�e :
#   - param�tres :
#	- spec : sp�cification des lignes normales, voir edition-tableau
#	- tab : tableau index� par les champs sp�cifi�s dans spec
#	- idnum : nom de la colonne repr�sentant l'identificateur num�rique
# Sortie :
#   - valeur de retour : une ligne de tableau pr�te pour arrgen
#
# Historique
#   2001/11/01 : pda      : sp�cification et documentation
#   2001/11/01 : pda      : conception
#   2002/05/03 : pda/jean : ajout du type menu
#   2002/05/06 : pda/jean : ajout du type textarea
#   2002/05/16 : pda      : conversion � arrgen
#

proc edition-ligne {spec tabvar idnum} {
    upvar $tabvar tab

    set ligne {Normal}
    foreach s $spec {
	set clef [lindex $s 0]
	set valeur $tab($clef)

	set type [lindex [lindex $s 1] 0]
	set opt [lindex [lindex $s 1] 1]

	set num $tab($idnum)
	set ref $clef$num

	switch $type {
	    texte {
		set item $valeur
	    }
	    string {
		set item [::webapp::form-text $ref 1 $opt 0 $valeur]
	    }
	    bool {
		set checked ""
		if {$valeur} then { set checked " CHECKED" }
		set item "<INPUT TYPE=checkbox NAME=$ref VALUE=1$checked>"
	    }
	    menu {
		set sel 0
		set i 0
		foreach e $opt {
		    # recherche obligatoirement le premier �l�ment de la liste
		    set id [lindex $e 0]
		    if {[string equal $id $valeur]} then {
			set sel $i
		    }
		    incr i
		}
		set item [::webapp::form-menu $ref 1 0 $opt [list $sel]]
	    }
	    textarea {
		set largeur [lindex $opt 0]
		set hauteur [lindex $opt 1]
		set item [::webapp::form-text $ref $hauteur $largeur 0 $valeur]
	    }
	}
	lappend ligne $item
    }

    return $ligne
}

#
# R�cup�re les modifications d'un formulaire g�n�r� par edition-tableau
# et les enregistre dans la base si n�cessaire
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s � la base
#	- spec : sp�cification des colonnes � modifier (voir plus bas)
#	- idnum : nom de la colonne repr�sentant l'identificateur num�rique
#	- table : nom de la table � modifier
#	- tabvar : tableau contenant les champs du formulaire
# Sortie :
#   - valeur de retour : cha�ne vide si ok, message d'erreur si pb
#
# Notes :
#   - le format du param�tre "spec" est {{colonne defval} ...}, o� :
#	- colonne est l'identificateur de la colonne dans la table
#	- defval, si pr�sent, indique la valeur par d�faut � mettre dans
#		la table car la valeur n'est pas fournie dans le formulaire
#   - la premi�re colonne de "spec" est utilis�e pour savoir s'il faut
#	ajouter ou supprimer l'entr�e correspondante
#
# Historique
#   2001/11/02 : pda      : sp�cification et documentation
#   2001/11/02 : pda      : codage
#   2002/05/03 : pda/jean : suppression contrainte sur les tickets
#

proc enregistrer-tableau {dbfd spec idnum table tabvar} {
    upvar $tabvar ftab

    #
    # Verrouillage de la table concern�e
    #

    if {! [::pgsql::execsql $dbfd "BEGIN WORK ; LOCK $table" msg]} then {
	return "Verrouillage impossible ('$msg')"
    }

    #
    # Dernier num�ro d'enregistrement attribu�
    #

    set max 0
    pg_select $dbfd "SELECT MAX($idnum) FROM $table" tab {
	set max $tab(max)
    }

    #
    # La clef pour savoir si une entr�e doit �tre d�truite (pour les
    # id existants) ou ajout�e (pour les nouveaux id)
    #


    set clef [lindex [lindex $spec 0] 0]

    #
    # Parcours des num�ros d�j� existants dans la base
    #

    set id 1

    for {set id 1} {$id <= $max} {incr id} {
	if {[info exists ftab(${clef}${id})]} {
	    remplir-tabval $spec "" $id ftab tabval

	    if {[string length $tabval($clef)] == 0} then {
		#
		# Destruction de l'entr�e.
		#

		set ok [retirer-entree $dbfd msg $id $idnum $table]
		if {! $ok} then {
		    ::pgsql::execsql $dbfd "ABORT WORK" m
		    #
		    # En cas de destruction impossible, il faut
		    # dire ce qu'on n'arrive pas � supprimer.
		    # Pour cela, il faut rechercher le vieux nom dans
		    # la base.
		    #

		    set oldclef ""
		    pg_select $dbfd "SELECT $clef FROM $table \
				    WHERE $idnum = $id" t {
			set oldclef $t($clef)
		    }
		    return "Erreur dans la suppression de '$oldclef' ('$msg')"
		}
	    } else {
		#
		# Modification de l'entr�e
		#

		set ok [modifier-entree $dbfd msg $id $idnum $table tabval]
		if {! $ok} then {
		    ::pgsql::execsql $dbfd "ABORT WORK" m
		    return "Erreur dans la modification de '$tabval($clef)' ('$msg')"
		}
	    }
	}
    }

    #
    # Nouvelles entr�es
    #

    set idnew 1
    while {[info exists ftab(${clef}n${idnew})]} {
	remplir-tabval $spec "n" $idnew ftab tabval

	if {[string length $tabval($clef)] > 0} then {
	    #
	    # Ajout de l'entr�e
	    #

	    set ok [ajouter-entree $dbfd msg $table tabval]
	    if {! $ok} then {
		::pgsql::execsql $dbfd "ABORT WORK" m
		return "Erreur dans l'ajout de '$tabval($clef)' ('$msg')"
	    }
	}

	incr idnew
    }

    #
    # D�verrouillage, et enregistrement des modifications avant la sortie
    #

    if {! [::pgsql::execsql $dbfd "COMMIT WORK" msg]} then {
	::pgsql::execsql $dbfd "ABORT WORK" m
	return "D�verrouillage impossible, modification annul�e ('$msg')"
    }

    return ""
}

#
# Lit les champs dans les formulaires, en compl�tant �ventuellement pour
# les champs bool�ens (checkbox) qui peuvent ne pas �tre pr�sents.
#
# Entr�e :
#   - param�tres :
#	- spec : voir enregistrer-tableau
#	- prefixe : "" (entr�e existante) ou "n" (nouvelle entr�e)
#	- num : num�ro de l'entr�e
#	- ftabvar : le tableau issu de get-data
#	- tabvalvar : le tableau � remplir
# Sortie :
#   - valeur de retour : aucune
#   - param�tre tabvalvar : contient les champs
#
# Note :
#   - si spec contient {{login} {nom}}, prefixe contient "n" et num "5"
#     alors on cherche ftab(loginn5) et ftab(nomn5)
#	 et on met �a dans tabval(login) et tabval(nom)
#
# Historique :
#   2001/04/01 : pda : conception
#   2001/04/03 : pda : documentation
#   2001/11/02 : pda : reprise et extension
#

proc remplir-tabval {spec prefixe num ftabvar tabvalvar} {
    upvar $ftabvar ftab
    upvar $tabvalvar tabval

    foreach coldefval $spec {

	set col [lindex $coldefval 0]

	if {[llength $coldefval] == 2} then {
	    #
	    # Valeur par d�faut : on ne la prend pas dans le formulaire
	    #

	    set val [lindex $coldefval 1]

	} else {

	    #
	    # Pas de valeur par d�faut : on recherche dans le formulaire.
	    # Si on ne trouve pas dans le formulaire, c'est un bool�en
	    # qui n'a pas �t� fourni, on prend 0 comme valeur.
	    #

	    set form ${col}${prefixe}${num}

	    if {[info exists ftab($form)]} then {
		set val [string trim [lindex $ftab($form) 0]]
	    } else {
		set val {0}
	    }
	}

	set tabval($col) $val
    }
}

#
# Modification d'une entr�e
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s � la base
#	- msg : variable contenant, en retour, le message d'erreur �ventuel
#	- id : l'id (valeur) de l'entr�e � modifier
#	- idnum : nom de la colonne des id de la table
#	- table : nom de la table � modifier
#	- tabvalvar : tableau contenant les valeurs � modifier
# Sortie :
#   - valeur de retour : 1 si ok, 0 si erreur
#   - param�tres :
#	- msg : message d'erreur si erreur
#
# Historique :
#   2001/04/01 : pda : conception
#   2001/04/03 : pda : documentation
#   2001/11/02 : pda : g�n�ralisation
#   2004/01/20 : pda/jean : ajout d'un attribut NULL si cha�ne vide (pour ipv6)
#

proc modifier-entree {dbfd msg id idnum table tabvalvar} {
    upvar $msg m
    upvar $tabvalvar tabval

    #
    # Tout d'abord, il n'y a pas besoin de modifier quoi que ce soit
    # si toutes les valeurs sont identiques.
    #

    set different 0
    pg_select $dbfd "SELECT * FROM $table WHERE $idnum = $id" tab {
	foreach attribut [array names tabval] {
	    if {[string compare $tabval($attribut) $tab($attribut)] != 0} then {
		set different 1
		break
	    }
	}
    }

    set ok 1

    if {$different} then {
	#
	# C'est diff�rent, il faut donc y aller...
	#

	set liste {}
	foreach attribut [array names tabval] {
	    if {[string equal $tabval($attribut) ""]} then {
		set v "NULL"
	    } else {
		set v "'[::pgsql::quote $tabval($attribut)]'"
	    }
	    lappend liste "$attribut = $v"
	}
	set sql "UPDATE $table SET [join $liste ,] WHERE $idnum = $id"
	set ok [::pgsql::execsql $dbfd $sql m]
    }

    return $ok
}

#
# Retrait d'une entree
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s � la base
#	- msg : variable contenant, en retour, le message d'erreur �ventuel
#	- id : l'id (valeur) de l'entr�e � modifier
#	- idnum : nom de la colonne des id de la table
#	- table : nom de la table � modifier
# Sortie :
#   - valeur de retour : 1 si ok, 0 si erreur
#   - param�tres :
#	- msg : message d'erreur si erreur
#
# Historique :
#   2001/04/03 : pda      : conception
#   2001/11/02 : pda      : g�n�ralisation
#   2002/05/03 : pda/jean : suppression contrainte sur les tickets
#

proc retirer-entree {dbfd msg id idnum table} {
    upvar $msg m

    set sql "DELETE FROM $table WHERE $idnum = $id"
    set ok [::pgsql::execsql $dbfd $sql m]

    return $ok
}

#
# Ajout d'une entr�e
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s � la base
#	- msg : variable contenant, en retour, le message d'erreur �ventuel
#	- table : nom de la table � modifier
#	- tabvalvar : tableau contenant les valeurs � ajouter
# Sortie :
#   - valeur de retour : 1 si ok, 0 si erreur
#   - param�tres :
#	- msg : message d'erreur si erreur
#
# Historique :
#   2001/04/01 : pda : conception
#   2001/04/03 : pda : documentation
#   2001/11/02 : pda : g�n�ralisation
#   2004/01/20 : pda/jean : ajout d'un attribut NULL si cha�ne vide (pour ipv6)
#

proc ajouter-entree {dbfd msg table tabvalvar} {
    upvar $msg m
    upvar $tabvalvar tabval

    #
    # Nom des colonnes
    #
    set cols [array names tabval]

    #
    # Valeur des colonnes
    #
    set vals {}
    foreach c $cols {
	if {[string equal $tabval($c) ""]} then {
	    set v "NULL"
	} else {
	    set v "'[::pgsql::quote $tabval($c)]'"
	}
	lappend vals $v
    }

    set sql "INSERT INTO $table ([join $cols ,]) VALUES ([join $vals ,])"
    set ok [::pgsql::execsql $dbfd $sql m]
    return $ok
}

##############################################################################
# Acc�s aux param�tres de configuration
##############################################################################

#
# Classe d'acc�s aux param�tres de configuration
#
# Cette classe repr�sente un moyen simple d'acc�der aux param�tres
# de configuration de l'application stock�s dans la base WebDNS.
#
# M�thodes :
# - setdb $dbfd
#	positionne l'acc�s � la base de donn�es dans laquelle sont
#	stock�s les param�tres
# - setlang
#	positionne la langue utilis�e pour rechercher les descriptions
# - class
#	renvoie toutes les classes connues
# - desc class-or-key
#	renvoie la description associ�e � la classe ou � la clef
# - keys [ class ]
#	renvoie toutes les clefs associ�es � la classe, ou toutes
#	les clefs connues
# - keytype key
#	renvoie le type de la clef donn�es, sous la forme d'une
#	liste {string|bool|text|menu x}. X n'est pr�sent que pour
#	le type menu
# - keyhelp key
#	renvoie le message d'aide associ� � une clef
# - get key
#	renvoie la valeur valeur associ�e � une clef
# - set key val
#	positionne la valeur associ�e � une clef, et retourne une
#	cha�ne vide, ou un message d'erreur
#
# Historique
#   2001/03/21 : pda     : conception de getconfig/setconfig
#   2003/12/08 : pda     : reprise depuis sos
#   2010/10/25 : pda     : transformation sous forme de classe
#

snit::type ::config {
    # database handle
    variable db ""

    # default language
    variable lang "fr"

    # configuration parameter specification
    variable configspec {
	{dns
	    {
		fr {Param�tres g�n�raux}
		en {General parameters}
	    }
	    {datefmt {string}
		fr {{Format d'affichage des dates/heures}
		    {Format d'affichage des dates et des heures,
			utilis� dans l'�dition et l'affichage des
			donn�es. Voir la page de manuel clock(n)
			de Tcl.}
		}
	    }
	    {jourfmt {string}
		fr {{Format d'affichage des jours}
		    {Format d'affichage des dates (sans l'heure).
		    Voir la page de manuel clock(n) de Tcl.}
		}
	    }
	}
	{dhcp
	    {
		fr {Param�tres DHCP}
		en {DHCP parameters}
	    }
	    {default_lease_time {string}
		fr {{default_lease_time}
		    {Valeur du param�tre DHCP "default_lease_time"
			utilis� lors de la g�n�ration d'intervalles
			dynamiques, en secondes. Cette valeur est
			utilis�e si le param�tre sp�cifique de
			l'intervalle est nul.}
		}
	    }
	    {max_lease_time {string}
		fr {{max_lease_time}
		    {Valeur du param�tre DHCP "max_lease_time"
		    utilis� lors de la g�n�ration d'intervalles
		    dynamiques, en secondes.  Cette valeur est
		    utilis�e si le param�tre sp�cifique de l'intervalle
		    est nul.}
		}
	    }
	    {min_lease_time {string}
		fr {{min_lease_time}
		    {Valeur minimale des param�tres DHCP sp�cifi�s
			dans les intervalles dynamiques. Cette
			valeur permet uniquement d'�viter qu'un
			correspondant r�seau pr�cise des param�tres
			de bail trop petits et g�n�re un trafic
			important.}
		}
	    }
	}
	{topo
	    {
		fr {Param�tres de topo}
		en {Topology parameters}
	    }
	    {topofrom {string}
		fr {{"From" des mails de topo}
		    {Champ "From" des mails envoy�s par le d�mon topod
			lors des d�tections de modification ou
			d'anomalie.}
		}
	    }
	    {topoto {string}
		fr {{Destinataire des mails de topo}
		    {Champ "To" des mails envoy�s par
			le d�mon topod lors des d�tection de
			modification ou d'anomalie.}
		}
	    }
	}
	{auth
	    {
		fr {Param�tres d'authentification}
		en {Authentification parameters}
	    }
	    {authmailfrom {bool}
		fr {{Utiliser le "From" sp�cifi� dans "auth"}
		    {Utiliser l'information provenant de l'application
			"auth" plut�t que le champ suivant.}
		}
	    }
	    {mailfrom {string}
		fr {{"From" des mails de modification de passwd}
		    {Champ "From" des mails envoy�s par l'application
			� un utilisateur lors des changements de
			mot de passe.}
		}
	    }
	    {authmailreplyto {bool}
		fr {{Utiliser le "Reply-To" sp�cifi� dans "auth"}
		    {Utiliser l'information provenant de l'application
			"auth" plut�t que le champ suivant.}
		}
	    }
	    {mailreplyto {string}
		fr {{"Reply-To" des mails de modification de passwd}
		    {Champ "Reply-To" des mails envoy�s par
			l'application � un utilisateur lors des
			changements de mot de passe.}
		}
	    }
	    {authmailcc {bool}
		fr {{Utiliser le "Cc" sp�cifi� dans "auth"}
		    {tiliser l'information provenant de l'application
			"auth" plut�t que le champ suivant.}
		}
	    }
	    {mailcc {string}
		fr {{"Cc" des mails de modification de passwd}
		    {Destinataire(s) auxiliaires des mail envoy�s
			par l'application � un utilisateur lors des
			changements de mot de passe.
			Cela peut �ventuellement �tre une liste d'adresses,
			l'espace faisant office de s�parateur.}
		}
	    }
	    {authmailbcc {bool}
		fr {{Utiliser le "Bcc" sp�cifi� dans "auth"}
		    {Utiliser l'information provenant de l'application
			"auth" plut�t que le champ suivant.}
		}
	    }
	    {mailbcc {string}
		fr {{"Bcc" des mails de modification de passwd}
		    {Destinataire(s) cach�(s) des mail envoy�s par
			l'application � un utilisateur lors des
			changements de mot de passe.  Cela peut
			�ventuellement �tre une liste d'adresses,
			l'espace faisant office de s�parateur.}
		}
	    }
	    {authmailsubject {bool}
		fr {{Utiliser le "Subject" sp�cifi� dans "auth"}
		    {Utiliser l'information provenant de l'application
			"auth" plut�t que le champ suivant.}
		}
	    }
	    {mailsubject {string}
		fr {{"Subject" des mails de moditication de passwd}
		    {Champ "Subject" des mails envoy�s par
			l'application � un utilisateur lors des
			changements de mot de passe.}
		}
	    }
	    {authmailbody {bool}
		fr {{Utiliser le corps sp�cifi� dans "auth"}
		    {Utiliser l'information provenant de l'application
			"auth" plut�t que le champ suivant.}
		}
	    }
	    {mailbody {text}
		fr {{Corps du mail de modification de passwd}
		    {Corps des mails envoy�s par l'application �
			un utilisateur lors des changements de mot
			de passe. Les param�tres suivants sont
			substitu�s: <ul><li>%1$s : login de
			l'utilisateur</li> <li>%2$s : mot de passe
			g�n�r�</li></ul>.}
		}
	    } {groupes {string}
		fr {{Groupes Web autoris�s}
		    {Liste de groupes (conform�ment � l'authentification
			Apache) autoris�s pour la cr�ation d'un
			utilisateur.  Si la liste est vide, tous
			les groupes existants dans la base
			d'authentification sont autoris�s.}
		}
	    }
	}
    }

    #
    # Internal representation of parameter specification
    #
    # (class)			{<cl1> ... <cln>}
    # (class:<cl1>)		{<k1> ... <kn>}
    # (class:<cl1>:desc:<lang>)	<desc>
    # (key:<k1>:type)		{string|bool|text|menu ...}
    # (key:<k1>:desc:<lang>)	<desc>
    # (key:<k1>:help:<lang>)	<text>
    #

    variable internal -array {}

    constructor {} {
	set internal(class) {}
	foreach class $configspec {
	    lassign $class classname classdesc

	    lappend internal(class) $classname
	    set internal(class:$classname) {}

	    array set t $classdesc
	    foreach lang [array names t] {
		set internal(class:$classname:desc:$lang) $t($lang)
	    }
	    unset t

	    foreach key [lreplace $class 0 1] {
		lassign $key keyname keytype

		lappend internal(class:$classname) $keyname
		set internal(key:$keyname:type) $keytype

		array set t [lreplace $key 0 1]
		foreach lang [array names t] {
		    lassign $t($lang) desc help
		    set internal(key:$keyname:desc:$lang) $desc
		    set internal(key:$keyname:help:$lang) $help
		}
		unset t
	    }
	}
    }

    method setdb {dbfd} {
	set db $dbfd
    }

    method setlang {lg} {
	set lang $lang
    }

    # returns all classes
    method class {} {
	return $internal(class)
    }

    # returns textual description of the given class or key
    method desc {cork} {
	set r $cork
	if {[info exists internal(class:$cork)]} then {
	    if {[info exists internal(class:$cork:desc:$lang)]} then {
		set r $internal(class:$cork:desc:$lang)
	    }
	} elseif {[info exists internal(key:$cork:type)]} {
	    if {[info exists internal(key:$cork:desc:$lang)]} then {
		set r $internal(key:$cork:desc:$lang)
	    }
	}
	return $r
    }

    # returns all keys associated with a class (default  : all classes)
    method keys {{class {}}} {
	if {[llength $class] == 0} then {
	    set class $internal(class)
	}
	set lk {}
	foreach c $class {
	    set lk [concat $lk $internal(class:$c)]
	}
	return $lk
    }

    # returns key type
    method keytype {key} {
	set r ""
	if {[info exists internal(key:$key:type)]} then {
	    set r $internal(key:$key:type)
	}
	return $r
    }

    # returns key help
    method keyhelp {key} {
	set r $key
	if {[info exists internal(key:$key:type)]} {
	    if {[info exists internal(key:$key:help:$lang)]} then {
		set r $internal(key:$key:help:$lang)
	    }
	}
	return $r
    }

    # returns key value
    method get {key} {
	set val {}
	pg_select $db "SELECT * FROM global.config WHERE clef = '$key'" tab {
	    set val $tab(valeur)
	}
	return $val
    }

    # set key value
    # returns empty string if ok, or an error message
    method set {key val} {
	set r ""
	set k [::pgsql::quote $key]
	set sql "DELETE FROM global.config WHERE clef = '$k'"
	if {[::pgsql::execsql $db $sql msg]} then {
	    set v [::pgsql::quote $val]
	    set sql "INSERT INTO global.config VALUES ('$k', '$v')"
	    if {! [::pgsql::execsql $db $sql msg]} then {
		set r "Cannot set '$key' to '$val': $msg"
	    }
	} else {
	    set r "Cannot fetch '$key': $msg"
	}

	return $r
    }
}

##############################################################################
# Librairie topo
##############################################################################

#
# Librairie TCL pour l'application de topologie
#
# Historique
#   2006/06/05 : pda             : conception de la partie topo
#   2006/05/24 : pda/jean/boggia : conception de la partie metro
#   2007/01/11 : pda             : fusion des deux parties
#   2008/10/01 : pda             : ajout de message de statut de la topo
#

set libconf(topodir)	%TOPODIR%
set libconf(graph)	%GRAPH%
set libconf(status)	%STATUS%

set libconf(extractcoll)	"%TOPODIR%/bin/extractcoll %s < %GRAPH%"
set libconf(extracteq)		"%TOPODIR%/bin/extracteq %s %s < %GRAPH%"

array set libconf {
    freq:2412	1
    freq:2417	2
    freq:2422	3
    freq:2427	4
    freq:2432	5
    freq:2437	6
    freq:2442	7
    freq:2447	8
    freq:2452	9
    freq:2457	10
    freq:2462	11
}

#
# Initialiser l'acc�s � la topo pour les scripts CGI
#
# Entr�e :
#   - param�tres :
#	- pageerr : fichier HTML contenant une page d'erreur
#	- attr : attribut n�cessaire pour ex�cuter le script ("corresp"/"admin")
#	- form : les param�tres du formulaire
#	- _ftab : tableau contenant en retour les champs du formulaire
#	- _dbfd : acc�s � la base en retour
#	- _uid : login de l'utilisateur, en retour
#	- _tabuid : tableau contenant les caract�ristiques de l'utilisateur
#		(cf lire-utilisateur)
#	- _ouid : login de l'utilisateur original, si substitu�, ou cha�ne vide
#	- _tabouid : idem tabuid pour l'utilisateur original
#	- _urluid : �l�ment d'url � ajouter en cas de subsitution d'uid
#	- _msgsta : message de status
# Sortie :
#   - valeur de retour : aucune
#   - param�tres :
#	- _ftab, _dbfd, _uid, _tabuid, _ouid, _tabouid, _msgsta : cf ci-dessus
#   - variables dont le nom est d�fini dans $form : modifi�es
#
# Remarque
#  - le champ de formulaire uid est syst�matiquement ajout� aux champs
#
# Historique
#   2007/01/11 : pda              : conception
#   2008/10/01 : pda              : ajout msgsta
#   2010/11/05 : pda/jean         : suppression param�tres
#

proc init-topo {pageerr attr form _ftab _dbfd _uid _tabuid _ouid _tabouid _urluid _msgsta} {
    global ah
    global libconf

    upvar $_ftab ftab
    upvar $_dbfd dbfd
    upvar $_uid uid
    upvar $_tabuid tabuid
    upvar $_ouid ouid
    upvar $_tabouid tabouid
    upvar $_urluid urluid
    upvar $_msgsta msgsta

    #
    # Pour le cas o� on est en mode maintenance
    #

    ::webapp::nologin %NOLOGIN% %ROOT% $pageerr

    #
    # En attendant de converger init-topo avec dnscontext
    #

    set ah [::webapp::authbase create %AUTO%]
    $ah configurelist %AUTH%

    #
    # Acc�s � la base SQL DNS
    #

    set dbfd [ouvrir-base %BASE% msg]
    if {[string length $dbfd] == 0} then {
	d error $msg
    }

    #
    # Le login de l'utilisateur (la page est prot�g�e par mot de passe)
    #

    set uid [::webapp::user]
    if {[string equal $uid ""]} then {
	d error "Pas de login : l'authentification a �chou�."
    }

    #
    # Les informations relatives � l'utilisateur
    #

    set msg [lire-correspondant $dbfd $uid tabuid]
    if {! [string equal $msg ""]} then {
	d error $msg
    }

    #
    # Est-ce que la page est r�serv�e � des administrateurs
    # (correspondant ou administrateur) ? Si oui, l'utilisateur
    # doit �tre dans la base DNS et pr�sent.
    #

    if {! [string equal $attr ""]} then {
	#
	# Si l'utilisateur n'est pas trouv� dans la base DNS
	# alors erreur (reproduit l'erreur dans lire-correspondant
	# que nous ignorons plus haut).
	#

	if {$tabuid(idcor) == -1} then {
	    d error "'$uid' n'est pas dans la base des correspondants."
	}

	#
	# Si le correspondant n'est plus marqu� comme "pr�sent" dans la base,
	# on ne lui autorise pas l'acc�s � l'application
	#

	if {! $tabuid(present)} then {
	    d error "D�sol�, $uid, mais vous n'�tes pas habilit�."
	}
	
	#
	# On v�rifie si la classe de l'utilisateur est autoris�e
	# � acc�der cgi, en fonction du niveau demand� par le cgi ($attr)
	# 
	#

        switch -- $attr {
            corresp {
		# si on arrive l�, c'est qu'on est correspondant
            }
            admin {
		if {! $tabuid(admin)} then {
                    d error "D�sol�, $uid, mais vous n'avez pas les droits suffisants"
                }
            }
            default {
                d error "Erreur interne sur demande d'attribut '$attr'"
            }
        }
    }

    #
    # R�cup�ration des param�tres du formulaire et importation des
    # valeurs dans des variables.
    #

    lappend form {uid 0 1}
    if {[llength [::webapp::get-data ftab $form]] == 0} then {
	d error "Formulaire non conforme aux sp�cifications"
    }

    uplevel 1 [list ::webapp::import-vars $_ftab]

    #
    # Substitution d'utilisateur
    #

    set nuid [string trim [lindex $ftab(uid) 0]]
    set urluid ""
    if {! [string equal $nuid ""]} then {
	if {$tabuid(admin)} then {
	    array set tabouid [array get tabuid]
	    array unset tabuid

	    set ouid $uid
	    set uid $nuid

	    set msg [lire-correspondant $dbfd $uid tabuid]
	    if {! [string equal $msg ""]} then {
		d error $msg
	    }

	    set urluid "uid=[::webapp::post-string $uid]"
	}
    }

    #
    # Lit le statut g�n�ral de la topo
    # (seulement si l'utilisateur cible est admin)
    #

    set msgsta ""
    if {$tabuid(admin)} then {
	set f $libconf(status)
	if {[file exists $f] && ![catch {set fd [open $f "r"]}]} then {
	    if {[gets $fd date] > 0} then {
		set msg [::webapp::html-string [read $fd]]
		regsub -all "\n" $msg "<br>" msg

		set texte [::webapp::helem "p" "Erreur de topo"]
		append texte [::webapp::helem "p" \
					    [::webapp::helem "font" $msg \
						    "color" "#ff0000" \
						] \
				    ]
		append texte [::webapp::helem "p" "... depuis $date"]

		set msgsta [::webapp::helem "div" $texte "class" "alerte"]
	    }
	    close $fd
	}
    }
}

#
# Utilitaire pour le tri des interfaces : compare deux noms d'interface
#
# Entr�e :
#   - param�tres :
#       - i1, i2 : deux noms d'interfaces
# Sortie :
#   - valeur de retour : -1, 0 ou 1 (cf string compare)
#
# Historique
#   2006/12/29 : pda : conception
#

proc compare-interfaces {i1 i2} {
    #
    # Isoler tous les mots
    # Ex: "GigabitEthernet1/0/1" -> " GigabitEthernet 1/0/1"
    #
    regsub -all {[A-Za-z]+} $i1 { & } i1
    regsub -all {[A-Za-z]+} $i2 { & } i2
    #
    # Retirer tous les caract�res sp�ciaux
    # Ex: " GigabitEthernet 1/0/1" -> " GigabitEthernet 1 0 1"
    #
    regsub -all {[^A-Za-z0-9]+} $i1 { } i1
    regsub -all {[^A-Za-z0-9]+} $i2 { } i2
    #
    # Retirer les espaces superflus
    #
    set i1 [string trim $i1]
    set i2 [string trim $i2]

    #
    # Comparer mot par mot
    #
    set r 0
    foreach m1 [split $i1] m2 [split $i2] {
	if {[regexp {^[0-9]+$} $m1] && [regexp {^[0-9]+$} $m2]} then {
	    if {$m1 < $m2} then {
		set r -1
	    } elseif {$m1 > $m2} then {
		set r 1
	    } else {
		set r 0
	    }
	} else {
	    set r [string compare $m1 $m2]
	}
	if {$r != 0} then {
	    break
	}
    }

    return $r
}

#
# Utilitaire pour le tri des adresses IP : compare deux adresses IP
#
# Entr�e :
#   - param�tres :
#       - ip1, ip2 : les adresses � comparer
# Sortie :
#   - valeur de retour : -1, 0 ou 1
#
# Historique
#   2006/06/20 : pda             : conception
#   2006/06/22 : pda             : documentation
#

proc comparer-ip {ip1 ip2} {
    set ip1 [::ip::normalize $ip1]
    set v1  [::ip::version $ip1]
    set ip2 [::ip::normalize $ip2]
    set v2  [::ip::version $ip2]

    set r 0
    if {$v1 == 4 && $v2 == 4} then {
	set l1 [split [::ip::prefix $ip1] "."]
	set l2 [split [::ip::prefix $ip2] "."]
	foreach e1 $l1 e2 $l2 {
	    if {$e1 < $e2} then {
		set r -1
		break
	    } elseif {$e1 > $e2} then {
		set r 1
		break
	    }
	}
    } elseif {$v1 == 6 && $v2 == 6} then {
	set l1 [split [::ip::prefix $ip1] ":"]
	set l2 [split [::ip::prefix $ip2] ":"]
	foreach e1 $l1 e2 $l2 {
	    if {"0x$e1" < "0x$e2"} then {
		set r -1
		break
	    } elseif {"0x$e1" > "0x$e2"} then {
		set r 1
		break
	    }
	}
    } else {
	set r [expr $v1 < $v2]
    }
    return $r
}

#
# Indique si une adresse IP est dans une classe
#
# Entr�e :
#   - param�tres :
#       - ip : adresse IP (ou CIDR) � tester
#	- net : CIDR de r�f�rence
# Sortie :
#   - valeur de retour : 0 (ip pas dans net) ou 1 (ip dans net)
#
# Historique
#   2006/06/22 : pda             : conception
#

proc ip-in {ip net} {
    set v [::ip::version $net]
    if {[::ip::version $ip] != $v} then {
	return 0
    }

    set defmask [expr "$v==4 ? 32 : 128"]

    set ip [::ip::normalize $ip]
    set net [::ip::normalize $net]

    set mask [::ip::mask $net]
    if {[string equal $mask ""]} then {
	set mask $defmask
    }

    set prefnet [::ip::prefix $net]
    regsub {(/[0-9]+)?$} $ip "/$mask" ip2
    set prefip  [::ip::prefix $ip2]

    return [string equal $prefip $prefnet]
}

#
# Valide l'id du point de collecte par rapport aux droits du correspondant.
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s � la base
#	- id : id du point de collecte (ou id+id+...)
#	- _tabcor : infos sur le correspondant
#	- _titre : titre du graphe
# Sortie :
#   - valeur de retour : message d'erreur ou cha�ne vide
#   - param�tre _titre : titre du graphe trouv�
#
# Historique
#   2006/08/09 : pda/boggia      : conception
#   2006/12/29 : pda             : parametre vlan pass� par variable
#   2008/07/30 : pda             : adaptation au nouvel extractcoll
#   2008/07/30 : pda             : codage de multiples id
#   2008/07/31 : pda             : ajout de |
#

proc verifier-metro-id {dbfd id _tabuid _titre} {
    upvar $_tabuid tabuid
    upvar $_titre titre
    global libconf

    #
    # Au cas o� les id seraient multiples
    #

    set lid [split $id "+|"]

    #
    # R�cup�rer la liste des points de collecte
    #

    set cmd [format $libconf(extractcoll) $tabuid(flagsr)]

    if {[catch {set fd [open "| $cmd" "r"]} msg]} then {
	return "Impossible de lire les points de collecte: $msg"
    }

    while {[gets $fd ligne] > -1} {
	set l [split $ligne]
	set kw [lindex $l 0]
	set i  [lindex $l 1]
	set n [lsearch -exact $lid $i]
	if {$n >= 0} then {
	    set idtab($i) $ligne
	    if {[info exists firstkw]} then {
		if {! [string equal $firstkw $kw]} then {
		    return "Types de points de collecte divergents" 
		}
	    } else {
		set firstkw $kw
	    }
	    set lid [lreplace $lid $n $n]
	}
    }
    catch {close $fd}

    #
    # Erreur si id pas trouv�
    #

    if {[llength $lid] > 0} then {
	return "Point de collecte '$id' non trouv�"
    }

    #
    # Essayer de trouver un titre convenable
    # 

    set lid [array names idtab]
    switch [llength $lid] {
	0 {
	    return "Aucun point de collecte s�lectionn�"
	}
	1 {
	    set i [lindex $lid 0]
	    set l $idtab($i)
	    switch $firstkw {
		trafic {
		    set eq    [lindex $l 2]
		    set iface [lindex $l 4]
		    set vlan  [lindex $l 5]

		    set titre "Trafic sur"
		    if {! [string equal $vlan "-"]} then {
			append titre " le vlan $vlan"
		    }
		    append titre " de l'interface $iface de $eq"
		}
		nbauthwifi -
		nbassocwifi {
		    set eq    [lindex $l 2]
		    set iface [lindex $l 4]
		    set ssid  [lindex $l 5]

		    set titre "Nombre"
		    if {[string equal $firstkw "nbauthwifi"]} then {
			append titre " d'utilisateurs authentifi�s" 
		    } else {
			append titre " de machines associ�es" 
		    }
		    append titre " sur le ssid $ssid de l'interface $iface de $eq"
		}
		default {
		    return "Erreur interne sur extractcoll"
		}
	    }
	}
	default {
	    switch $firstkw {
		trafic {
		    set titre "Trafic"
		    set le {}
		    foreach i $lid {
			set l $idtab($i)
			set eq    [lindex $l 2]
			set iface [lindex $l 4]
			set vlan  [lindex $l 5]

			set e "$eq/$iface"
			if {! [string equal $vlan "-"]} then {
			    append e ".$vlan"
			}
			lappend le $e
		    }
		    set le [join $le " et "]
		    append titre " sur $le"
		}
		nbauthwifi -
		nbassocwifi {
		    if {[string equal $firstkw "nbauthwifi"]} then {
			set titre "Nombre d'utilisateurs authentifi�s"
		    } else {
			set titre "Nombre de machines associ�es"
		    }
		    foreach i $lid {
			set l $idtab($i)
			set eq    [lindex $l 2]
			set iface [lindex $l 4]
			set ssid  [lindex $l 5]

			set e "$eq/$iface ($ssid)"
			lappend le $e
		    }
		    set le [join $le " et "]
		    append titre " sur $le"
		}
		default {
		    return "Erreur interne sur extractcoll"
		}
	    }
	}
    }

    return ""
}

#
# R�cup�re une expression r�guli�re caract�risant la liste des
# �quipements autoris�s.
#
# Entr�e :
#   - param�tres :
#       - dbfd : acc�s � la base DNS
#	- rw : read (0) ou write (1)
#	- idgrp : id du groupe dans la base DNS
# Sortie :
#   - valeur de retour : liste de listes de la forme
#		{{re_allow_1 ... re_allow_n} {re_deny_1 ... re_deny_n}}
#
# Historique
#   2006/08/10 : pda/boggia      : cr�ation avec un fichier sur disque
#   2010/11/03 : pda/jean        : les donn�es sont dans la base
#

proc lire-eq-autorises {dbfd rw idgrp} {

    set r {}

    #
    # Traiter d'abord les allow, puis les deny
    #

    foreach allow_deny {1 0} {
	set sql "SELECT pattern
			FROM topo.dr_eq
			WHERE idgrp = $idgrp
			    AND rw = $rw
			    AND allow_deny = $allow_deny"
	set d {}
	pg_select $dbfd $sql tab {
	    lappend d $tab(pattern)
	}
	lappend r $d
    }
    return $r
}

#
# R�cup�re un graphe du m�trologiseur et le renvoie
#
# Entr�e :
#   - param�tres :
#       - url : l'URL pour aller chercher le graphe sur le m�trologiseur
# Sortie :
#   - aucune sortie, le graphe est r�cup�r� et renvoy� sur la sortie standard
#	avec l'en-t�te HTTP qui va bien
#
# Historique
#   2006/05/17 : jean       : cr�ation pour dhcplog
#   2006/08/09 : pda/boggia : r�cup�ration, mise en fct et en librairie
#   2010/11/15 : pda        : suppression param�tre pageerr
#

proc gengraph {url} {
    package require http			;# tcllib

    set token [::http::geturl $url]
    set status [::http::status $token]

    if {![string equal $status "ok"]} then {
	set code [::http::code $token]
	d error "Acc�s impossible ($code)"
    }

    upvar #0 $token state

    # 
    # D�terminer le type d'image
    # 

    array set meta $state(meta)
    switch -exact $meta(Content-Type) {
	image/png {
	    set contenttype "png"
	}
	image/jpeg {
	    set contenttype "jpeg"
	}
	image/gif {
	    set contenttype "gif"
	}
	default {
	    set contenttype "html"
	}
    }

    # 
    # Renvoyer le r�sultat
    # 

    ::webapp::send $contenttype $state(body)
}

#
# Lit et d�code une date entr�e dans un formulaire
#
# Entr�e :
#   - param�tres :
#       - date : la date saisie par l'utilisateur dans le formulaire
#	- heure : heure (00:00:00 pour l'heure de d�but, 23:59:59 pour fin)
# Sortie :
#   - valeur de retour : la date en format postgresql, ou "" si rien
#
# Historique
#   2000/07/18 : pda : conception
#   2000/07/23 : pda : ajout de l'heure
#   2001/03/12 : pda : mise en librairie
#   2008/07/30 : pda : ajout cas sp�cial pour 24h (= 23:59:59)
#

proc decoder-date {date heure} {
    set date [string trim $date]
    if {[string length $date] == 0} then {
	set datepg ""
    }
    if {[string equal $heure "24"]} then {
	set heure "23:59:59"
    }
    set liste [split $date /]
    switch [llength $liste] {
	1	{
	    set jj   [lindex $liste 0]
	    set mm   [clock format [clock seconds] -format "%m"]
	    set yyyy [clock format [clock seconds] -format "%Y"]
	    set datepg "$mm/$jj/$yyyy $heure"
	}
	2	{
	    set jj   [lindex $liste 0]
	    set mm   [lindex $liste 1]
	    set yyyy [clock format [clock seconds] -format "%Y"]
	    set datepg "$mm/$jj/$yyyy $heure"
	}
	3	{
	    set jj   [lindex $liste 0]
	    set mm   [lindex $liste 1]
	    set yyyy [lindex $liste 2]
	    set datepg "$mm/$jj/$yyyy $heure"
	}
	default	{
	    set datepg ""
	}
    }

    if {! [string equal $datepg ""]} then {
	if {[catch {clock scan $datepg}]} then {
	    set datepg ""
	}
    }
    return $datepg
}

#
# Convertit une fr�quence radio 802.11b/g (bande des 2,4 GHz)
# en canal 802.11b/g
#
# Entr�e :
#   - param�tres :
#       - freq : la fr�quence
# Sortie :
#   - valeur de retour : cha�ne exprimant le canal
#
# Historique
#   2008/07/30 : pda : conception
#   2008/10/17 : pda : canal "dfs"
#

proc conv-channel {freq} {
    global libconf

    switch -- $freq {
	dfs {
	    set channel "auto"
	}
	default {
	    if {[info exists libconf(freq:$freq)]} then {
		set channel $libconf(freq:$freq)
	    } else {
		set channel "$freq MHz"
	    }
	}
    }
    return $channel
}

#
# R�cup�re la liste des interfaces d'un �quipement
#
# Entr�e :
#   - param�tres :
#	- eq : nom de l'�quipement
#	- tabuid() : tableau contenant les flags de restriction pour l'utilisateur
#   - variables globales :
#	- libconf(extracteq) : appel � extracteq
# Sortie :
#   - valeur de retour : liste de la forme
#		{eq type model location iflist array}
#	o� iflist est la liste tri�e des interfaces
#	et array est pr�t pour "array set" pour donner un tableau de la forme
#	tab(iface) {nom edit radio stat mode desc lien natif {vlan...}}
#	(cf sortie de extracteq)
#
# Historique
#   2010/11/03 : pda      : cr�ation
#   2010/11/15 : pda      : suppression param�tre pageerr
#

proc eq-iflist {eq _tabuid} {
    global libconf
    upvar $_tabuid tabuid

    #
    # Lire les informations de l'�quipement dans le graphe
    # Ces informations sont filtr�es par tabuid qui n'affiche
    # que les vlans autoris�s.
    #

    set cmd [format $libconf(extracteq) $tabuid(flagsr) $eq]
    set fd [open "|$cmd" "r"]
    while {[gets $fd ligne] > -1} {
	switch [lindex $ligne 0] {
	    eq {
		set r [lreplace $ligne 0 0]

		set location [lindex $r 3]
		if {$location eq "-"} then {
		    set location ""
		} else {
		    set location [binary format H* $location]
		}
		set r [lreplace $r 3 3 $location]
	    }
	    iface {
		set if [lindex $ligne 1]
		set tabiface($if) [lreplace $ligne 0 0]
	    }
	}
    }
    if {[catch {close $fd} msg]} then {
	d error "Erreur lors de la lecture de l'�quipement '$eq'"
    }

    #
    # Trier les interfaces pour les pr�senter dans le bon ordre
    #

    set iflist [lsort -command compare-interfaces [array names tabiface]]

    #
    # Pr�senter la valeur de retour
    #

    lappend r $iflist
    lappend r [array get tabiface]

    return $r
}
