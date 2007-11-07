#
# Librairie TCL pour l'application de topologie
#
# Historique
#   2006/06/05 : pda             : conception de la partie topo
#   2006/05/24 : pda/jean/boggia : conception de la partie metro
#   2007/01/11 : pda             : fusion des deux parties
#

set libconf(topodir)	%TOPODIR%
set libconf(graph)	%GRAPH%

set libconf(extractcoll)	"%TOPODIR%/bin/extractcoll %s < %GRAPH%"

#
# Initialiser l'acc�s � la topo pour les scripts CGI
#
# Entr�e :
#   - param�tres :
#	- nologin : nom du fichier test� pour le mode "maintenance"
#	- base : nom de la base
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
# Sortie :
#   - valeur de retour : aucune
#   - param�tres :
#	- _ftab, _dbfd, _uid, _tabuid, _ouid, _tabouid : cf ci-dessus
#   - variables dont le nom est d�fini dans $form : modifi�es
#
# Remarque
#  - le champ de formulaire uid est syst�matiquement ajout� aux champs
#
# Historique
#   2007/01/11 : pda              : conception
#

proc init-topo {nologin base pageerr attr form _ftab _dbfd _uid _tabuid _ouid _tabouid _urluid} {
    global libconf

    upvar $_ftab ftab
    upvar $_dbfd dbfd
    upvar $_uid uid
    upvar $_tabuid tabuid
    upvar $_ouid ouid
    upvar $_tabouid tabouid
    upvar $_urluid urluid

    #
    # Pour le cas o� on est en mode maintenance
    #

    ::webapp::nologin $nologin %ROOT% $pageerr

    #
    # Acc�s � la base SQL DNS
    #

    set dbfd [ouvrir-base $base msg]
    if {[string length $dbfd] == 0} then {
	::webapp::error-exit $pageerr $msg
    }

    #
    # Le login de l'utilisateur (la page est prot�g�e par mot de passe)
    #

    set uid [::webapp::user]
    if {[string equal $uid ""]} then {
	::webapp::error-exit $pageerr \
		"Pas de login : l'authentification a �chou�."
    }

    #
    # Les informations relatives � l'utilisateur
    #

    set msg [lire-utilisateur $dbfd $uid tabuid]
    if {! [string equal $msg ""]} then {
	::webapp::error-exit $pageerr $msg
    }

    #
    # Est-ce que la page est r�serv�e � des administrateurs
    # (correspondant ou administrateur) ? Si oui, l'utilisateur
    # doit �tre dans la base DNS et pr�sent.
    #

    if {! [string equal $attr ""]} then {
	#
	# Si l'utilisateur n'est pas trouv� dans la base DNS
	# alors erreur (reproduit l'erreur dans lire-correspondant-...
	# que nous ignorons plus haut).
	#

	if {$tabuid(idcor) == -1} then {
	    ::webapp::error-exit $pageerr \
		"'$uid' n'est pas dans la base des correspondants."
	}

	#
	# Si le correspondant n'est plus marqu� comme "pr�sent" dans la base,
	# on ne lui autorise pas l'acc�s � l'application
	#

	if {! $tabuid(present)} then {
	    ::webapp::error-exit $pageerr \
		"D�sol�, $uid, mais vous n'�tes pas habilit�."
	}
	
	#
	# On v�rifie si la classe de l'utilisteur est autoris� 
	# � acc�der cgi, en fonction du niveau demand� par le cgi ($attr)
	# 
	#

        switch -- $attr {
            corresp {
		# si on arrive l�, c'est qu'on est correspondant
            }
            admin {
		if {! $tabuid(admin)} then {
                    ::webapp::error-exit $pageerr \
                        "D�sol�, $uid, mais vous n'avez pas les droits suffisants"
                }
            }
            default {
                ::webapp::error-exit $pageerr \
                        "Erreur interne sur demande d'attribut '$attr'"
            }
        }
    }

    #
    # R�cup�ration des param�tres du formulaire et importation des
    # valeurs dans des variables.
    #

    lappend form {uid 0 1}
    if {[llength [::webapp::get-data ftab $form]] == 0} then {
	::webapp::error-exit $pageerr \
	    "Formulaire non conforme aux sp�cifications"
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

	    set msg [lire-utilisateur $dbfd $uid tabuid]
	    if {! [string equal $msg ""]} then {
		::webapp::error-exit $pageerr $msg
	    }

	    set urluid "uid=[::webapp::post-string $uid]"
	}
    }
}


#
# Lit les informations d'un utilisateur
#
# Entr�e :
#   - param�tres :
#	- dbfd : commande pour afficher le graphe en ascii
#	- uid : login de l'utilisateur
#	- _tabuid : tableau en retour, contenant les champs
#		login	login demand�
#		idcor	id dans la base
#		idgrp	id du groupe dans la base
#		groupe	nom du groupe
#		present	1 si marqu� "pr�sent" dans la base
#		admin	1 si admin
#		reseaux	liste des r�seaux autoris�s
#		eq	regexp des �quipements autoris�s
#		flags	flags -n/-e � utiliser dans les commandes topo
# Sortie :
#   - valeur de retour : message d'erreur ou cha�ne vide
#   - param�tre _tabuid : cf ci-dessus
#
# Historique
#   2007/01/11 : pda             : conception
#

proc lire-utilisateur {dbfd uid _tabuid} {
    upvar $_tabuid tabuid

    #
    # Le segment de code qui suit a des ressemblances avec
    # la fonction "lire-correspondant-par-login" de la libdns,
    # mais celle-ci utilise le package auth que nous ne pouvons
    # pas utiliser.
    #

    set tabuid(login)		$uid

    #
    # Essayer de lire les caract�ristiques de l'utilisateur dans la
    # base DNS : c'est alors un correspondant.
    #

    set quid [::pgsql::quote $uid]
    set tabuid(idcor) -1
    set sql "SELECT * FROM corresp, groupe
			WHERE corresp.login = '$quid'
			     AND corresp.idgrp = groupe.idgrp"
    pg_select $dbfd $sql tab {
	set tabuid(idcor)	$tab(idcor)
	set tabuid(idgrp)	$tab(idgrp)
	set tabuid(present)	$tab(present)
	set tabuid(groupe)	$tab(nom)
	set tabuid(admin)	$tab(admin)
    }

    if {$tabuid(idcor) == -1} then {
	return ""
    }

    #
    # Lire les CIDR des r�seaux autoris�s (fonction de la libdns)
    #

    set tabuid(reseaux) [liste-reseaux-autorises $dbfd $tabuid(idgrp) "dhcp"]

    #
    # Lire les �quipements
    #

    set tabuid(eq) [lire-eq-autorises $dbfd $tabuid(groupe)]

    #
    # Construire les flags
    #

    set flags {}
    if {! $tabuid(admin)} then {
	if {! [string equal $tabuid(eq) ""]} then {
	    lappend flags "-e" $tabuid(eq)
	}
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
    set tabuid(flags) [join $flags " "]

    return ""
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
# R�cup�re une liste de points de collecte pour un ensemble de CIDR
# (IPv4 et/ou IPv6) donn�
#
# Entr�e :
#   - param�tres :
#	- cidr4 : adresse IPv4 du r�seau
#	- cidr6 : adresse IPv6 du r�seau
#	- regexp : expression r�guli�re sur les noms d'�quipements
# Sortie :
#   - valeur de retour : liste dont le premier �l�ment est "erreur" ou "ok"
#	- si "erreur", le deuxi�me �l�ment est le message
#	- si "ok", le deuxi�me �l�ment est la liste trouv�e, au format :
#		{{id eq if vlan} ...}
#
# XXX : n'est plus utilis� que par l'accueil de la m�trologie (obsol�te)
#
# Historique
#   2006/05/24 : pda/jean/boggia : conception
#   2006/08/10 : pda/boggia      : ajout regexp
#

proc extraire-collecte {cidr4 cidr6 regexp} {
    global libconf

    if {! [string equal $cidr4 ""]} then {
	set parm "-n $cidr4"
    } elseif {! [string equal $cidr6 ""]} then {
	set parm "-n $cidr6"
    } elseif {! [string equal $regexp ""]} then {
	set parm "-e $regexp"
    } else {
	return {erreur {Erreur interne : extraction de point de collecte sans crit�re (cidr4=$cidr4, cidr6=$cidr6, regexp=$regexp}}
    }

    set cmd "$libconf(topodir)/bin/extractcoll $parm < $libconf(graph)"

    if {[catch {set fd [open "| $cmd" "r"]} msg]} then {
	return [list "erreur" $msg]
    } else {
	set res {}
	while {[gets $fd ligne] > -1} {
	    lappend res $ligne
	}
	close $fd
    }

    return [list "ok" $res]
}

#
# Valide l'id du point de collecte par rapport aux droits du correspondant.
#
# Entr�e :
#   - param�tres :
#	- dbfd : acc�s � la base
#	- id : id du point de collecte
#	- _tabcor : infos sur le correspondant
#	- _eq : en sortie, nom de l'�quipement
#	- _iface : en sortie, nom de l'interface
#	- _vlan : en sortie, num�ro du vlan
# Sortie :
#   - valeur de retour : message d'erreur ou cha�ne vide
#   - param�tre _eq : nom de l'�quipement trouv�
#   - param�tre _iface : nom de l'interface trouv�e
#   - param�tre _vlan : num�ro du vlan trouv�, ou "-"
#
# Historique
#   2006/08/09 : pda/boggia      : conception
#   2006/12/29 : pda             : parametre vlan pass� par variable
#

# XXX pour l'instant, on ne v�rifie que la coh�rence de l'id
# du graphe
#
# XXX : voir avec extraire-collecte : il y a des choses � mettre en commun !

proc verifier-metro-id {dbfd id _tabuid _eq _iface _vlan} {
    upvar $_tabuid tabuid
    upvar $_eq eq  $_iface iface  $_vlan vlan
    global libconf

    #
    # R�cup�rer la liste des points de collecte
    #

    set cmd [format $libconf(extractcoll) $tabuid(flags)]

    if {[catch {set fd [open "| $cmd" "r"]} msg]} then {
	set r "Impossible de lire les points de collecte: $msg"
    } else {
	set r "Point de collecte '$id' non trouv�"
	while {[gets $fd ligne] > -1} {
	    #
	    # D�couper la ligne
	    #	<id> <eq> <iface> <vlan>
	    # en �l�ments de liste
	    #
	    set l [split $ligne]

	    #
	    # V�rification simpliste
	    #

	    if {[llength $l] != 4} then {
		set r "Erreur interne sur extractcoll"
		break
	    }

	    #
	    # On sort si on trouve, en positionnant les variables
	    # eq et iface
	    #

	    if {[string equal [lindex $l 0] $id]} then {
		set eq    [lindex $l 1]
		set iface [lindex $l 2]
		set vlan  [lindex $l 3]
		set r ""
		break
	    }
	}
	catch {close $fd}
    }

    return $r
}

#
# R�cup�re une expression r�guli�re caract�risant la liste des
# �quipements autoris�s.
#
# XXX : cette fonction est � r��crire pour utiliser la base DNS
#	et � int�grer dans la libdns.tcl
# XXX : remplacer groupe par idgrp
#
# Entr�e :
#   - param�tres :
#       - dbfd : acc�s � la base DNS
#	- groupe : nom du groupe DNS (XXX : � supprimer ASAP)
#	- idgrp : id du groupe dans la base DNS (XXX : � utiliser � la place)
# Sortie :
#   - valeur de retour : expression r�guli�re, ou cha�ne vide
#
# Historique
#   2006/08/10 : pda/boggia      : cr�ation
#

proc lire-eq-autorises {dbfd groupe} {
    set fd [open "%DESTDIR%/lib/droits-eq.data" "r"]
    set r ""
    while {[gets $fd ligne] > -1} {
	regsub "#.*" $ligne "" $ligne
	set ligne [string trim $ligne]
	if {[regexp {^([^\s]+)\s+(.*)} $ligne bidon g re]} then {
	    if {[string equal $g $groupe]} then {
		set r $re
		break
	    }
	}
    }
    close $fd
    return $r
}

#
# R�cup�re un graphe du m�trologiseur et le renvoie
#
# Entr�e :
#   - param�tres :
#       - url : l'URL pour aller chercher le graphe sur le m�trologiseur
#	- err : une page d'erreur le cas �ch�ant
# Sortie :
#   - aucune sortie, le graphe est r�cup�r� et renvoy� sur la sortie standard
#	avec l'en-t�te HTTP qui va bien
#
# Historique
#   2006/05/17 : jean            : cr�ation pour dhcplog
#   2006/08/09 : pda/boggia      : r�cup�ration, mise en fct et en librairie
#

# cf /local/services/www/sap/dhcplog/bin/gengraph

proc gengraph {url err} {
    package require http

    set token [::http::geturl $url]
    set status [::http::status $token]

    if {![string equal $status "ok"]} then {
	set code [::http::code $token]
	::webapp::error-exit $err "Acc�s impossible ($code)"
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
#

proc decoder-date {date heure} {
    set date [string trim $date]
    if {[string length $date] == 0} then {
	set datepg ""
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
