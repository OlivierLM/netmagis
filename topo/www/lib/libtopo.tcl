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
#

proc init-topo {nologin base pageerr attr form _ftab _dbfd _uid _tabuid _ouid _tabouid _urluid _msgsta} {
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

    set cmd [format $libconf(extractcoll) $tabuid(flags)]

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
