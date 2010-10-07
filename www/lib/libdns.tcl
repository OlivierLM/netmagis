#
# Librairie TCL pour l'application de gestion DNS.
#
# $Id: libdns.tcl,v 1.15 2008-09-24 07:33:51 pda Exp $
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

# set debug(base)	dbname=dns-debug
# set debug(mail)	{pda@crc.u-strasbg.fr}

##############################################################################
# Param�tres de la librairie
##############################################################################

set libconf(tabdroits) {
    global {
	chars {12 normal}
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

set libconf(tabreseaux) {
    global {
	chars {12 normal}
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
	chars {12 normal}
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
	chars {12 normal}
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
#   - variables globales :
#	- debug(base) : si la variable existe, elle doit contenir le
#		nom d'une base qui sera utilis�e pour tous les acc�s
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

    #
    # On ne sait jamais... Intercepter la lecture �ventuellement.
    #

    if {[info exists debug(base)]} then {
	set base $debug(base)
    }

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

#
# Initialiser l'acc�s � DNS pour les scripts CGI
#
# Entr�e :
#   - param�tres :
#	- nologin : nom du fichier test� pour le mode "maintenance"
#	- auth : param�tres d'authentification
#	- base : nom de la base
#	- pageerr : fichier HTML contenant une page d'erreur
#	- attr : attribut n�cessaire pour ex�cuter le script (XXX : un seul attr)
#	- form : les param�tres du formulaire
#	- ftabvar : tableau contenant en retour les champs du formulaire
#	- dbfdvar : acc�s � la base en retour
#	- loginvar : login de l'utilisateur, en retour
#	- tabcorvar : tableau contenant les caract�ristiques de l'utilisateur
#		(login, password, nom, prenom, mel, tel, fax, mobile, adr,
#			idcor, idgrp, present)
#	- logparam : param�tres de log (subsys, m�thode, param�tres de la m�th)
# Sortie :
#   - valeur de retour : aucune
#   - param�tres :
#	- ftabvar : cf ci-dessus
#	- dbfdvar : cf ci-dessus
#	- loginvar : cf ci-dessus
#	- tabcorvar : cf ci-dessus
#
# Historique
#   2001/06/18 : pda      : conception
#   2002/12/26 : pda      : actualisation et mise en service
#   2003/05/13 : pda/jean : int�gration dans dns et utilisation de auth
#   2007/10/05 : pda/jean : adaptation aux objets "authuser" et "authbase"
#   2007/10/26 : jean     : ajout du log
#

proc init-dns {nologin auth base pageerr attr form ftabvar dbfdvar loginvar tabcorvar logparam} {
    global ah
    global log
    upvar $ftabvar ftab
    upvar $dbfdvar dbfd
    upvar $loginvar login
    upvar $tabcorvar tabcor

    #
    # Pour le cas o� on est en mode maintenance
    #

    ::webapp::nologin $nologin %ROOT% $pageerr

    #
    # Acc�s � la base d'authentification
    #

    set ah [::webapp::authbase create %AUTO%]
    $ah configurelist $auth

    #
    # Acc�s � la base
    #

    set dbfd [ouvrir-base $base msg]
    if {[string length $dbfd] == 0} then {
	::webapp::error-exit $pageerr $msg
    }

    #
    # Initialisation du log
    #

    set logsubsys [lindex $logparam 0]
    set logmethod [lindex $logparam 1]
    set logmedium [lindex $logparam 2]
    set log [::webapp::log create %AUTO% -subsys $logsubsys -method $logmethod -medium $logmedium]

    #
    # Le login de l'utilisateur (la page est prot�g�e par mot de passe)
    #

    set login [::webapp::user]
    if {[string compare $login ""] == 0} then {
	::webapp::error-exit $pageerr \
		"Pas de login : l'authentification a �chou�."
    }

    #
    # Lire toutes les caract�ristiques du correspondant
    #

    set msg [lire-correspondant-par-login $dbfd $login tabcor]
    if {! [string equal $msg ""]} then {
	::webapp::error-exit $pageerr $msg
    }

    #
    # Si le correspondant n'est plus marqu� comme "pr�sent" dans la base,
    # on ne lui autorise pas l'acc�s � l'application
    #

    if {! $tabcor(present)} then {
	::webapp::error-exit $pageerr \
	    "D�sol�, $tabcor(prenom) $tabcor(nom), mais vous n'�tes pas habilit�."
    }

    #
    # Page accessible seulement en mode "admin"
    #

    if {[llength $attr] > 0} then {
	#
	# XXX : pour l'instant, test d'un seul attribut seulement
	#

	if {! [attribut-correspondant $dbfd $tabcor(idcor) $attr]} then {
	    ::webapp::error-exit $pageerr \
		"D�sol�,  $login, mais vous n'avez pas les droits suffisants"
	}
    }

    #
    # R�cup�ration des param�tres du formulaire
    #

    if {[string length $form] > 0} then {
	if {[llength [::webapp::get-data ftab $form]] == 0} then {
	    ::webapp::error-exit $pageerr \
		"Formulaire non conforme aux sp�cifications"
	}
    }
}

#
# Initialiser l'acc�s � DNS pour les scripts "batch"
#
# Entr�e :
#   - param�tres :
#	- nologin : nom du fichier test� pour le mode "maintenance"
#	- auth : param�tres d'authentification
#	- base : nom de la base
#	- dbfdvar : acc�s � la base en retour
#	- login : login de l'utilisateur
#	- tabcorvar : tableau contenant les caract�ristiques de l'utilisateur
#		(login, password, nom, prenom, mel, tel, fax, mobile, adr,
#			idcor, idgrp, present)
#	- logparam : param�tres de log (subsys, m�thode, param�tres de la m�th)
# Sortie :
#   - valeur de retour : message d'erreur, ou cha�ne vide si pas d'erreur
#   - param�tres :
#	- dbfdvar : cf ci-dessus
#	- tabcorvar : cf ci-dessus
#
# Historique
#   2004/09/24 : pda/jean : conception
#   2007/10/05 : pda/jean : adaptation aux objets "authuser" et "authbase"
#   2007/10/26 : jean     : ajout du log
#

proc init-dns-util {nologin auth base dbfdvar login tabcorvar logparam} {
    global ah
    global log
    upvar $dbfdvar dbfd
    upvar $tabcorvar tabcor

    #
    # Pour le cas o� on est en mode maintenance
    #

    if {[file exists $nologin]} then {
	set fd [open $nologin r]
	set message [read $fd]
	close $fd
	return "Connexion refus�e.\n$message"
    }

    #
    # Acc�s � la base d'authentification
    #

    set ah [::webapp::authbase create %AUTO%]
    $ah configurelist $auth

    #
    # Acc�s � la base
    #

    set dbfd [ouvrir-base $base msg]
    if {[string length $dbfd] == 0} then {
	return "Acc�s � la base DNS impossible\n$msg"
    }

    #
    # Initialisation du log
    #

    set logsubsys [lindex $logparam 0]
    set logmethod [lindex $logparam 1]
    set logmedium [lindex $logparam 2]
    set log [::webapp::log create %AUTO% -subsys $logsubsys -method $logmethod -medium $logmedium]

    #
    # Lire toutes les caract�ristiques du correspondant
    #

    set msg [lire-correspondant-par-login $dbfd $login tabcor]
    if {! [string equal $msg ""]} then {
	return "Utilisateur '$login' : $msg"
    }

    #
    # Si le correspondant n'est plus marqu� comme "pr�sent" dans la base,
    # on ne lui autorise pas l'acc�s � l'application
    #

    if {! $tabcor(present)} then {
	return "Utilisateur '$login' non pr�sent"
    }

    return ""
}

# 
# �crire une ligne dans le syst�me de log
# 
# Entr�e :
#   - param�tres :
#	- evenement : nom de l'evenement (exemples : supprhost, suppralias etc.)
#	- login     : identifiant du correspondant effectuant l'action
#	- message   : message de log (par exemple les parametres de l'evenement)
#
# Sortie :
#   rien
#
# Historique :
#   2007/10/?? : jean : conception
#

proc writelog {evenement login msg} {
    global log
    global env

    if {[info exists env(REMOTE_ADDR) ]} then {
	set ip $env(REMOTE_ADDR)    
    } else {
	set ip ""
    }

    $log log "" $evenement $login $ip $msg
    
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
			FROM groupe, corresp \
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
#	- tabcorvar : tableau des attributs du correspondant (en retour)
# Sortie :
#   - valeur de retour : message d'erreur ou cha�ne vide
#   - param�tre tabcorvar : les attributs en retour
#
# Historique
#   2003/05/13 : pda/jean : conception
#   2007/10/05 : pda/jean : adaptation aux objets "authuser" et "authbase"
#

proc lire-correspondant-par-login {dbfd login tabcorvar} {
    global ah
    upvar $tabcorvar tabcor

    catch {unset tabcor}

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
	set tabcor($c) [$u get $c]
    }

    $u destroy

    #
    # Lire les autres caract�ristiques, propres � cette application.
    #

    set qlogin [::pgsql::quote $login]
    set tabcor(idcor) -1
    set sql "SELECT * FROM corresp, groupe
			WHERE corresp.login = '$qlogin'
			    AND corresp.idgrp = groupe.idgrp"
    pg_select $dbfd $sql tab {
	set tabcor(idcor)	$tab(idcor)
	set tabcor(idgrp)	$tab(idgrp)
	set tabcor(present)	$tab(present)
	set tabcor(groupe)	$tab(nom)
	set tabcor(admin)	$tab(admin)
    }

    if {$tabcor(idcor) == -1} then {
	return "'$login' n'est pas dans la base des correspondants."
    }

    return ""
}

proc lire-correspondant-par-id {dbfd idcor tabcorvar} {
    global ah
    upvar $tabcorvar tabcor

    catch {unset tabcor}

    #
    # Lire les caract�ristiques, propres � cette application.
    #

    set tabcor(idcor) -1
    set sql "SELECT * FROM corresp, groupe
			WHERE corresp.idcor = $idcor
			    AND corresp.idgrp = groupe.idgrp"
    pg_select $dbfd $sql tab {
	set tabcor(login)	$tab(login)
	set tabcor(idcor)	$tab(idcor)
	set tabcor(idgrp)	$tab(idgrp)
	set tabcor(present)	$tab(present)
	set tabcor(groupe)	$tab(nom)
	set tabcor(admin)	$tab(admin)
    }

    if {$tabcor(idcor) == -1} then {
	return "Le correspondant d'id $idcor n'est pas dans la base des correspondants."
    }

    #
    # Lire les caract�ristiques communes � toutes les applications
    #

    set u [::webapp::authuser create %AUTO%]
    if {[catch {set n [$ah getuser $tabcor(login) $u]} m]} then {
	return "Probl�me dans la base d'authentification ($m)"
    }
    
    switch $n {
	0 {
	    return "'$tabcor(login)' n'est pas dans la base d'authentification."
	}
	1 { 
	    # Rien
	}
	default {
	    return "Trop d'utilisateurs trouv�s"
	}
    }

    foreach c {login password nom prenom mel tel mobile fax adr} {
	set tabcor($c) [$u get $c]
    }

    $u destroy

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
    set sql "SELECT idrr FROM rr WHERE nom = '$qnom' AND iddom = $iddom"
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
    set sql "SELECT idrr FROM rr_ip WHERE adr = '$adr'"
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
#

proc lire-rr-par-id {dbfd idrr tabrr} {
    upvar $tabrr trr

    set fields {nom iddom
	mac iddhcpprofil idhinfo droitsmtp commentaire respnom respmel
	idcor date}

    catch {unset trr}
    set trr(idrr) $idrr

    set trouve 0
    set columns [join $fields ", "]
    set sql "SELECT $columns FROM rr WHERE idrr = $idrr"
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
	    set sql "SELECT nom FROM dhcpprofil
				WHERE iddhcpprofil = $trr(iddhcpprofil)"
	    pg_select $dbfd $sql tab {
		set trr(dhcpprofil) $tab(nom)
	    }
	}
	set sql "SELECT texte FROM hinfo WHERE idhinfo = $trr(idhinfo)"
	pg_select $dbfd $sql tab {
	    set trr(hinfo) $tab(texte)
	}
	set sql "SELECT nom FROM domaine WHERE iddom = $trr(iddom)"
	pg_select $dbfd $sql tab {
	    set trr(domaine) $tab(nom)
	}
	set trr(ip) {}
	pg_select $dbfd "SELECT adr FROM rr_ip WHERE idrr = $idrr" tab {
	    lappend trr(ip) $tab(adr)
	}
	set trr(mx) {}
	pg_select $dbfd "SELECT priorite,mx FROM rr_mx WHERE idrr = $idrr" tab {
	    lappend trr(mx) [list $tab(priorite) $tab(mx)]
	}
	set trr(cname) ""
	pg_select $dbfd "SELECT cname FROM rr_cname WHERE idrr = $idrr" tab {
	    set trr(cname) $tab(cname)
	}
	set trr(aliases) {}
	pg_select $dbfd "SELECT idrr FROM rr_cname WHERE cname = $idrr" tab {
	    lappend trr(aliases) $tab(idrr)
	}
	set trr(rolemail) ""
	pg_select $dbfd "SELECT heberg FROM role_mail WHERE idrr = $idrr" tab {
	    set trr(rolemail) $tab(heberg)
	}
	set trr(adrmail) {}
	pg_select $dbfd "SELECT idrr FROM role_mail WHERE heberg = $idrr" tab {
	    lappend trr(adrmail) $tab(idrr)
	}
	set trr(roleweb) 0
	pg_select $dbfd "SELECT 1 FROM role_web WHERE idrr = $idrr" tab {
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

    set sql "DELETE FROM rr WHERE idrr = $idrr"
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
    set sql "DELETE FROM rr_cname WHERE idrr = $idrr"
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
    set sql "DELETE FROM rr_ip WHERE idrr = $idrr AND adr = '$adr'"
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
    set sql "DELETE FROM rr_mx WHERE idrr = $idrr"
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
    set sql "DELETE FROM role_mail WHERE idrr = $idrr"
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
    set sql "DELETE FROM role_web WHERE idrr = $idrr"
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
#

proc ajouter-rr {dbfd nom iddom mac iddhcpprofil idhinfo droitsmtp
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
    set sql "INSERT INTO rr
		    (nom, iddom,
			mac,
			iddhcpprofil,
			$hinfodef
			droitsmtp, commentaire, respnom, respmel,
			idcor)
		VALUES
		    ('$nom', $iddom,
			$qmac,
			$iddhcpprofil,
			$hinfoval
			$droitsmtp, '$qcomment', '$qrespnom', '$qrespmel',
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
#	- idcor : l'index du correspondant
# Sortie :
#   - valeur de retour : cha�ne vide (ok) ou non vide (message d'erreur)
#
# Historique
#   2002/05/03 : pda/jean : conception
#   2004/10/05 : pda      : changement du format de date
#

proc touch-rr {dbfd idrr idcor} {
    set date [clock format [clock seconds]]
    set sql "UPDATE rr SET idcor = $idcor, date = '$date' WHERE idrr = $idrr"
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
    set sql "SELECT COUNT(*) AS ndroitsmtp FROM groupe WHERE droitsmtp = 1"
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
	    set sql "SELECT nom FROM dhcpprofil
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
    pg_select $dbfd "SELECT iddom FROM domaine WHERE nom = '$domaine'" tab {
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
    set sql "SELECT dr_dom.iddom FROM dr_dom, corresp
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
		FROM relais_dom rd, rr r, domaine d
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
			    FROM dhcprange
			    WHERE '$ip' >= min AND '$ip' <= max"
	    pg_select $dbfd $sql tab {
		set r "$ip est dans l'intervalle DHCP \[$tab(min)..$tab(max)\]"
	    }
	    if {! [string equal $r ""]} then {
		break
	    }
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
	::webapp::error-exit $pageerr "Pas de login : l'authentification a �chou�"
    }

    #
    # R�cup�ration des informations du correspondant
    # et validation de ses droits.
    #

    set qlogin [::pgsql::quote $login]
    set idcor -1
    set sql "SELECT idcor, present FROM corresp WHERE login = '$qlogin'"
    pg_select $dbfd $sql tab {
	set idcor	$tab(idcor)
	set present	$tab(present)
    }

    if {$idcor == -1} then {
	::webapp::error-exit $pageerr "D�sol�, vous n'�tes pas dans la base des correspondants."
    }
    if {! $present} then {
	::webapp::error-exit $pageerr "D�sol�, $login, mais vous n'�tes pas habilit�."
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
    set sql "SELECT idgrp FROM corresp WHERE idcor = $idcor"
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
    pg_select $dbfd "SELECT idhinfo FROM hinfo WHERE texte = '$qtexte'" tab {
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
	set sql "SELECT iddhcpprofil FROM dhcpprofil WHERE nom = '$qtexte'"
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
    set sql "SELECT texte FROM hinfo \
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
		FROM dr_dhcpprofil dr, dhcpprofil p, corresp c
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
			    FROM dhcpprofil
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
#   - err : page d'erreur
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
#

proc menu-domaine {dbfd idcor champ where sel err} {
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
	    ::webapp::error-exit $err "D�sol�, mais vous n'avez aucun domaine actif"
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
		FROM domaine, dr_dom, corresp
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
    return [::pgsql::getcols $dbfd groupe "nom <> ''" "nom ASC" $l]
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
#   - valeur de retour : liste � 6 �l�ments, chaque �l�ment �tant
#	le code HTML associ�.
#
# Historique
#   2002/05/23 : pda/jean : sp�cification et conception
#   2005/04/06 : pda      : ajout des profils dhcp
#   2007/10/23 : pda/jean : ajout des correspondants
#   2008/07/23 : pda/jean : ajout des droits du groupe
#

proc info-groupe {dbfd idgrp} {
    global libconf

    #
    # R�cup�ration des droits particuliers : admin et droitsmtp
    #

    set donnees {}
    set sql "SELECT admin, droitsmtp FROM groupe WHERE idgrp = $idgrp"
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
	lappend donnees [list DROIT "Administration de l'application" $admin]
	lappend donnees [list DROIT "Gestion des �metteurs SMTP" $droitsmtp]
    }
    if {[llength $donnees] == 2} then {
	set tabdroits [::arrgen::output "html" $libconf(tabdroits) $donnees]
    } else {
	set tabdroits "Erreur sur les droits du groupe"
    }

    #
    # R�cup�ration des correspondants
    #

    set lcor {}
    set sql "SELECT login FROM corresp WHERE idgrp=$idgrp ORDER BY login"
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
		FROM reseau r, dr_reseau d, etablissement e, communaute c
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
			FROM dr_ip
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
		    FROM dr_ip
		    WHERE NOT (adr <<= ANY (
				SELECT r.adr4
					FROM reseau r, dr_reseau d
					WHERE r.idreseau = d.idreseau
						AND d.idgrp = $idgrp
				UNION
				SELECT r.adr6
					FROM reseau r, dr_reseau d
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
			FROM dr_dom, domaine
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
    set sql "SELECT p.nom, dr.tri, p.texte \
			FROM dhcpprofil p, dr_dhcpprofil dr
			WHERE p.iddhcpprofil = dr.iddhcpprofil \
				AND dr.idgrp = $idgrp \
			ORDER BY dr.tri, p.nom"
    pg_select $dbfd $sql tab {
	lappend donnees [list DHCP $tab(nom) $tab(texte)]
    }
    if {[llength $donnees] > 0} then {
	set tabdhcpprofil [::arrgen::output "html" $libconf(tabdhcpprofil) $donnees]
    } else {
	set tabdhcpprofil "Aucun profil DHCP autoris�"
    }

    return [list    $tabdroits \
		    $tabcorresp \
		    $tabreseaux \
		    $tabcidrhorsreseau \
		    $tabdomaines \
		    $tabdhcpprofil \
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
			FROM reseau r, dr_reseau d
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
		    FROM dr_reseau d, reseau r
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
    set sql "SELECT droitsmtp FROM groupe g, corresp c 
				WHERE g.idgrp = c.idgrp AND c.idcor = $idcor"
    set r 0
    pg_select $dbfd $sql tab {
	set r $tab(droitsmtp)
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
# Lecture des param�tres de configuration
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s � la base
#	- clef : clef de configuration
# Sortie :
#   - valeur de retour : clef de configuration
#
# Historique
#   2001/03/21 : pda     : conception
#   2003/12/08 : pda     : reprise de sos
#

proc getconfig {dbfd clef} {
    set valeur {}
    pg_select $dbfd "SELECT * FROM config WHERE clef = '$clef'" tab {
	set valeur $tab(valeur)
    }
    return $valeur
}

#
# �criture des param�tres de configuration
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s � la base
#	- clef : clef de configuration
#	- valeur : la valeur de la clef
#	- varmsg : message d'erreur lors de l'�criture, si besoin
# Sortie :
#   - valeur de retour : 1 si ok, ou 0 en cas d'erreur
#   - param�tre varmsg : message d'erreur �ventuel
#
# Historique
#   2001/03/21 : pda     : conception
#   2003/12/08 : pda     : reprise de sos
#

proc setconfig {dbfd clef valeur varmsg} {
    upvar $varmsg msg

    set r 0
    set sql "DELETE FROM config WHERE clef = '$clef'"
    if {[::pgsql::execsql $dbfd $sql msg]} then {
	set v [::pgsql::quote $valeur]
	set sql "INSERT INTO config VALUES ('$clef', '$v')"
	if {[::pgsql::execsql $dbfd $sql msg]} then {
	    set r 1
	}
    }

    return $r
}
