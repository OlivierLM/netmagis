#
#
# Librairie de fonctions TCL utilisables dans les scripts CGI
#
# Historique
#   1999/02/25 : pda : conception en package
#   2000/07/19 : pda : ajout de generer-menu
#   2001/02/28 : pda : suppression de get-raw-data ajout� par je ne sais pas qui
#   2001/05/02 : pda : utilisation du package Pgtcl pour l'acc�s � PostgreSQL
#   2001/10/20 : pda : ajout de la proc�dure sortie-html
#   2002/05/11 : pda : ajout de la proc�dure sortie-latex
#   2002/05/11 : pda : ajout des variables tmp et pdflatex
#   2002/05/20 : pda : ajout de la proc�dure send � la place de sortie-*
#   2002/06/04 : pda : ajout de la proc�dure nologin
#   2002/12/26 : pda : ajout de la proc�dure error-exit
#   2003/06/07 : pda : ajout de la proc�dure call-cgi
#   2003/06/27 : pda : ajout de la proc�dure cgi-exec
#   2003/09/29 : pda : ajout de la proc�dure mail
#   2003/11/05 : pda : utilisation de string equal � la place de string length
#   2004/02/12 : pda/jean : ajout form-bool
#   2005/04/13 : pda : correction d'un bug dans form-text
#   2006/08/29 : pda : ajout de import-vars
#   2007/10/05 : pda/jean : ajout des objets auth et user
#   2007/10/23 : pda/jean : ajout de l'objet log
#   2008/06/12 : pda/jean : ajout de interactive-tree et helem
#   2010/11/05 : pda      : m�thode opened-postgresql pour l'objet log
#

# packages n�cessaires pour l'acces � la base d'authentification

package require snit ;			# tcllib >= 1.10
package require ldapx ;			# tcllib >= 1.10
package require pgsql ;			# package local

# package require Pgtcl

package provide webapp 1.11

#
# Candidates � suppression
#	generer-menu	-> pb
#	

namespace eval webapp {
    namespace export log pathinfo user \
	form-field form-yesno form-bool form-menu form-text form-hidden \
	hide-parameters file-subst \
	helem interactive-tree \
	get-data import-vars valid-email \
	post-string html-string \
	call-cgi \
	mail \
	random \
	nologin send error-exit \
	debug \
	cgidebug \
	\
	generer-menu cacher-parametres substituer \
	\
	cgi-exec

    variable tmpdir	/tmp
    variable pdflatex	/usr/local/bin/pdflatex
    variable debuginfos {}
    variable sendmail	{/usr/sbin/sendmail -t}

    # element HTML (4.01) sans tag de fermeture
    # cf http://www.w3.org/TR/1999/REC-html401-19991224/index/elements.html
    variable noendtags	{area base basefont br col frame hr img input isindex
				link meta param}
    # url des images (pour la g�n�ration d'arbre interactif)
    # relativement � la racine du serveur web
    variable treeimages	/images

    # code Javascript de l'arbre interactif
    variable treejs {
	<script type="text/javascript">
	  <!--
	    // fonction pour initialiser la vue de l'arborescence
	    // id : id de l'ul de l'arborescence � initialiser
	    // disp : "none" ou "block"
	    // Cette fonction masque tous les ul compris sous l'id,
	    // puis affiche juste l'ul correspondant � l'id
	    function multide(id, disp) {
	      var x = document.getElementById (id) ;
	      // v�rification de coh�rence
	      if (! x || x.nodeName != "UL")
		return 'PAS UN UL' ;
	      tab = x.getElementsByTagName ("UL") ;
	      for (var i = 0 ; i < tab.length ; i++) {
		tab [i].style.display = disp ;
	      }
	      x.style.display = "block" ;
	    }

	    // fonction de d�roulement/enroulement
	    // img : un objet de type IMG (�l�ment HTML) dont on
	    //   veut d�rouler/enrouler la liste associ�e
	    //	 Typiquement, img est l'image "+" ou "-", et
	    //   on veut d�rouler/enrouler le ul qui suit
	    //   dans la liste des fr�res
	    function de(img) {
	      var ul ;
	      // v�rification de coh�rence
	      if (img.nodeName != "IMG")
		return 'PAS UN IMG'
	      // parcourir tous les fr�res pour trouver l'UL qui doit suivre
	      ul = img ;
	      while (ul && ul.nodeName != "UL")
		ul = ul.nextSibling ;
	      if (! ul || ul.nodeName != "UL")
		return 'PAS UN UL'
	      // d�rouler ou enrouler ?
	      if (ul.style.display == "none") {
		// d�rouler
		ul.style.display = "block" ;
		img.src = "%TREEIMAGES%/tree-minus.gif" ;
		img.alt = "[-]" ;
	      } else {
		// enrouler
		ul.style.display = "none" ;
		img.src = "%TREEIMAGES%/tree-plus.gif" ;
		img.alt = "[+]" ;
	      }
	      return 'OK' ;
	    }
	  //-->
	</script>
    }

    # CSS de l'arbre interactif (avec un trou correspondant � l'id)
    variable treecss {
	<style type="text/css">
	<!--

	ul#%ID% ul {
	  background: url("%TREEIMAGES%/tree-line.gif") repeat-y 0px 0px;
	  padding-left: 24px;
	  margin-left: 0;
	}

	ul#%ID% ul.last {
	  background: none;
	}

	ul#%ID% li {
	  list-style: none;
	  padding: 0;
	  margin: 0;
	  line-height: 100%;
	}

	ul#%ID% a {
	  padding: 0;
	  margin: 0;
	}

	ul#%ID% img {
	  padding: 0;
	  margin: 0;
	}

	ul#%ID% img.click {
	  cursor: pointer;
	}

	-->
	</style>
    }
}

##############################################################################
# Debug de certaines fonctions du script
##############################################################################

#
# Positionne les informations de debug
#
# Entr�e :
#   - param�tres :
#	- infos : listes de comportements � d�boguer
# Sortie :
#   - valeur de retour : -
#   - variables globales :
#	- debuginfo : les informations de debug souhait�es
#
# Note : informations de debug possibles
#	latexfiles : laisse les fichiers latex en l'�tat dans /tmp
#	latexsource : sort le source latex et non le g�n�r� pdf
#
# Historique :
#   2002/05/12 : pda : conception
#

proc ::webapp::debug {infos} {
    set ::webapp::debuginfos $infos
}


##############################################################################
# Fichier de log
##############################################################################

#
# Ajoute une ligne dans un fichier de log
#
# Entr�e :
#   - param�tres :
#	- fichier : nom du fichier de log
#	- message : message � envoyer dans le log
#   - variables d'environnement :
#	- SCRIPT_NAME : voir proc�dure script-name
#	- REMOTE_HOST, REMOTE_ADDR : nom du client, ou � d�faut son adresse IP
# Sortie :
#   - pas de sortie
#
# Historique :
#   1999/04/06 : pda : conception
#   2000/12/12 : ??? : signalement de l'erreur d'ouverture sur stderr
#

proc ::webapp::log {fichier message} {
    global env

    set name [::webapp::script-name]

    if {[info exists env(REMOTE_HOST)]} then {
	set remote $env(REMOTE_HOST)
    } else {
	set remote $env(REMOTE_ADDR)
    }

    set date [clock format [clock seconds]]

    if {[catch {open $fichier a} fd] == 0} then {
	puts $fd [format "%s %s %s %s" $name $date $remote $message]
	close $fd
    } else {
	puts stderr "erreur ouverture $fichier"
    }
}



##############################################################################
# Traitement des variables d'environnement
##############################################################################

#
# Renvoie le contenu de la variable PATH_INFO
#
# Entr�e :
#   - variables d'environnement :
#	- PATH_INFO : une cha�ne de la forme "/relative/path/to/script"
# Sortie :
#   - valeur de retour : liste des composants
#
# Historique :
#   1994/08/xx : pda : conception et codage
#   1999/02/25 : pda : documentation
#

proc ::webapp::pathinfo {} {
    global env

    # v�rifie que la variable existe
    if {! [info exists env(PATH_INFO)]} then {
	return {}
    }

    # d�coupe la variable en �l�ments de liste
    set path [split $env(PATH_INFO) /]
    # le premier �l�ment est nul puisque le chemin commence par "/"
    set path [lreplace $path 0 0]

    return $path
}


#
# Renvoie le nom du script courant
#
# Entr�e :
#   - variables d'environnement :
#	- SCRIPT_NAME : une cha�ne de la forme "/relative/path/to/script"
# Sortie :
#   - valeur de retour :
#	- le nom, ou vide si rien
#
# Historique :
#   1994/08/xx : pda : conception et codage
#   1999/02/25 : pda : documentation
#   1999/07/14 : pda : changement d'interface
#

proc ::webapp::script-name {} {
    global env

    if {[info exists env(SCRIPT_NAME)]} then {
	set n [split $env(SCRIPT_NAME) "/"]
	set nm [lindex $n [expr [llength $n]-1]]
    } else {
	set nm {}
    }
    return $nm
}

#
# Renvoie le nom de l'utilisateur courant (authentification apache)
#
# Entr�e :
#   - variables d'environnement :
#	- REMOTE_USER : une cha�ne de la forme "login""
# Sortie :
#   - valeur de retour :
#	- le nom, ou vide si rien
#
# Historique :
#   1999/10/24 : pda : conception et codage
#

proc ::webapp::user {} {
    global env

    if {[info exists env(REMOTE_USER)]} then {
	set nm $env(REMOTE_USER)
    } else {
	set nm {}
    }
    return $nm
}

##############################################################################
# G�n�ration de fragments de code HTML
##############################################################################

#
# G�n�ration du code HTML pour r�aliser un menu d�roulant ou une
# liste � choix multiples
# A SUPPRIMER DES QUE POSSIBLE (form-menu est mieux)
#
# Entr�e :
#   - param�tres :
#	- var : variable du formulaire pour ce menu
#	- taille : taille de la liste (1 si menu d�roulant)
#	- multiple : 1 si choix multiple autoris�, 0 sinon
#	- liste : liste d'items
#	- lsel : liste des indices des items s�lectionn�s
# Sortie :
#   - code HTML g�n�r�
#
# Historique :
#   2000/07/19 : pda : conception
#   2000/07/24 : pda : ajout du param�tre multiple
#

proc ::webapp::generer-menu {var taille multiple liste lsel} {
    set indice 0

    set optsel [lindex $lsel 0]
    set lsel [lreplace $lsel 0 0]

    set m ""
    if {$multiple} then { set m "MULTIPLE" }

    set html "<SELECT SIZE=\"$taille\" NAME=\"$var\" $m>\n"

    foreach item $liste {
	append html "<OPTION"
	if {[string equal $indice $optsel]} then {
	    append html " SELECTED"
	    set optsel [lindex $lsel 0]
	    set lsel [lreplace $lsel 0 0]
	}
	append html ">[::webapp::html-string $item]\n"
	incr indice
    }
    append html "</SELECT>"

    return $html
}

#
# G�n�ration de balises HTML conformes � HTML 4.01
#
# Entr�e :
#   - param�tres :
#	- tag : balise HTML ("img", "ul", "a", etc.)
#	- content : texte associ� au tag (entre les balises)
#	- args : attributs de la balise
# Sortie :
#   - code HTML g�n�r�
#
# Exemple :
#   puts [helem "a" "cliquer ici" "href" "http://www.tcl.tk"]
#
# Historique :
#   2008/06/12 : pda/jean/lauce : int�gration webapp
#

proc ::webapp::helem {tag content args} {
    set tag [string tolower $tag]
    set r "<$tag"
    foreach {attr value} $args {
	set attr [string tolower $attr]
	append r " $attr=\"$value\""
    }
    append r ">$content"
    # ne mettre une fermeture que pour les tags qui ne figurent pas
    # dans la liste des tags sans fermeture
    if {[lsearch $::webapp::noendtags $tag] == -1} then {
	append r "</$tag>"
    }
    return $r
}

#
# G�n�ration du code HTML pour �diter un champ
#
# Entr�e :
#   - param�tres :
#	- spec : sp�cification du champ, sous la forme
#		string [<largeur> [<largeurmax>]]
#		hidden
#		text [<hauteur> [<largeur>]]
#		menu <item> ... <item>, o� <item>={<valeur envoy�e> <affich�e>}
#		list <mono/multi> <taille> <item> ... <item>
#		password [<largeur> [<largeurmax>]]
#		bool
#		hidden
#		yesno [fmt]
#	- var : variable du formulaire
#	- val : valeur initiale (par d�faut)
# Sortie :
#   - code HTML g�n�r�
#
# Historique :
#   2003/08/01 : pda : conception
#

proc ::webapp::form-field {spec var val} {
    set nargs [llength $spec]
    switch -- [lindex $spec 0] {
	string {
	    switch $nargs {
		2 {
		    set largeur	[lindex $spec 1]
		    set max	0
		}
		3 {
		    set largeur [lindex $spec 1]
		    set max     [lindex $spec 2]
		}
		default {
		    set largeur	0
		    set max	0
		}
	    }
	    set h [::webapp::form-text $var 1 $largeur $max $val]
	}
	bool {
	    set h [::webapp::form-bool $var $val]
	}
	password {
	    set hval [::webapp::unpost-string $val]
	    set h <INPUT TYPE=PASSWORD NAME=$var VALUE=\"$hval\">"
	}
	text {
	    switch $nargs {
		2 {
		    set hauteur	[lindex $spec 1]
		    set largeur	0
		}
		3 {
		    set hauteur [lindex $spec 1]
		    set largeur [lindex $spec 2]
		}
		default {
		    set hauteur	0
		    set largeur	0
		}
	    }
	    set h [::webapp::form-text $var $hauteur $largeur 0 $val]
	}
	menu {
	    set items [lreplace $spec 0 0]
	    set h [::webapp::form-menu $var 1 0 $items $val]
	}
	list {
	    set monomulti [lindex $spec 1]
	    set taille    [lindex $spec 2]
	    set items	  [lreplace $spec 0 2]
	    set multiple 0
	    if {[string equal $monomulti "multi"]} then {
		set multiple 1
	    }
	    set h [::webapp::form-menu $var $taille $multiple $items $val]
	}
	yesno {
	    set fmt {%1$s&nbsp;Oui&nbsp;&nbsp;&nbsp;%2$s&nbsp;Non}
	    if {$nargs >= 2} then {
		set fmt [lindex $spec 1]
	    }
	    set h [::webapp::form-yesno $var $val $fmt]
	}
	hidden {
	    set h [::webapp::form-hidden $var $val]
	}
	default {
	    set h "ERREUR"
	}
    }
    return $h
}

#
# G�n�ration du code HTML pour r�aliser un item oui/non
#
# Entr�e :
#   - param�tres :
#	- var : variable du formulaire pour ce menu
#	- defval : valeur par d�faut
#	- fmt : format pour la sortie de l'HTML
# Sortie :
#   - code HTML g�n�r�
#
# Historique :
#   2001/06/18 : pda : conception
#

proc ::webapp::form-yesno {var defval fmt} {
    set oui "<INPUT TYPE=radio NAME=$var VALUE=1"
    set non "<INPUT TYPE=radio NAME=$var VALUE=0"
    if {! [string equal $defval ""] && $defval} then {
	append oui " CHECKED"
    } else {
	append non " CHECKED"
    }
    append oui ">"
    append non ">"
    set html [format $fmt $oui $non]
    return $html
}

#
# G�n�ration du code HTML pour r�aliser un item bool�en (case coch�e ou non)
#
# Entr�e :
#   - param�tres :
#	- var : variable du formulaire pour ce menu
#	- defval : valeur par d�faut (=0 ou !=0)
# Sortie :
#   - code HTML g�n�r�
#
# Historique :
#   2004/02/12 : pda/jean : conception
#

proc ::webapp::form-bool {var defval} {
    set checked ""
    if {[regexp {^[0-9]+$} $defval] && $defval} then {
	set checked " CHECKED"
    }
    set html "<INPUT TYPE=CHECKBOX NAME=$var VALUE=1$checked>"
    return $html
}

#
# G�n�ration du code HTML pour r�aliser un menu d�roulant ou une
# liste � choix multiples
#
# Entr�e :
#   - param�tres :
#	- var : variable du formulaire pour ce menu
#	- taille : taille de la liste (1 si menu d�roulant)
#	- multiple : 1 si choix multiple autoris�, 0 sinon
#	- liste : liste de couples { <valeur renvoy�e> <item affich�> }
#	- lsel : liste des indices des items s�lectionn�s
# Sortie :
#   - code HTML g�n�r�
#
# Historique :
#   2001/04/27 : pda      : conception
#   2004/01/16 : pda/jean : correction d'un bug si lsel non tri�
#

proc ::webapp::form-menu {var taille multiple liste lsel} {
    set indice 0

    set lsel [lsort -integer $lsel]

    set optsel [lindex $lsel 0]
    set lsel [lreplace $lsel 0 0]

    set m ""
    if {$multiple} then { set m "MULTIPLE" }

    set html "<SELECT SIZE=\"$taille\" NAME=\"$var\" $m>\n"

    foreach item $liste {
	set valeur  [::webapp::html-string [lindex $item 0]]
	set libelle [::webapp::html-string [lindex $item 1]]

	append html "<OPTION"

	if {! [string equal $valeur ""]} then {
	    append html " VALUE=\"$valeur\""
	}

	if {[string equal $indice $optsel]} then {
	    append html " SELECTED"
	    set optsel [lindex $lsel 0]
	    set lsel [lreplace $lsel 0 0]
	}

	append html ">$libelle\n"

	incr indice
    }
    append html "</SELECT>\n"

    return $html
}

#
# G�n�ration du code HTML pour r�aliser une ligne de texte
#
# Entr�e :
#   - param�tres :
#	- var : variable du formulaire pour cette ligne
#	- hauteur : hauteur de l'entr�e, ou 0 pour la hauteur par d�faut
#	- largeur : taille de l'entr�e, ou 0 pour la taille par d�faut
#	- max : nb maximum de caract�res autoris�s, 0 pour la valeur par d�faut
#	- valeur : valeur initiale
# Sortie :
#   - code HTML g�n�r�
#
# Historique :
#   2001/04/27 : pda : conception
#   2005/04/13 : pda : manquait ">" si input sans valeur par d�faut
#

proc ::webapp::form-text {var hauteur largeur max valeur} {
    set v [::webapp::html-string $valeur]
    if {$hauteur <= 1} then {
	#
	# Simple ligne
	#
	set html "<INPUT TYPE=text NAME=\"$var\""

	if {$largeur > 0} then {
	    append html " SIZE=\"$largeur\""
	}

	if {$max > 0} then {
	    append html " MAXLENGTH=\"$max\""
	}

	if {! [string equal $valeur ""]} then {
	    append html " VALUE=\"$v\""
	}

	append html ">"
    } else {
	#
	# Zone de texte multi-ligne
	#
	set html "<TEXTAREA NAME=\"$var\" ROWS=\"$hauteur\""

	if {$largeur > 0} then {
	    append html " COLS=\"$largeur\""
	}
	append html ">$v</TEXTAREA>"
    }

    return $html
}

#
# G�n�ration du code HTML pour r�aliser un champ hidden
#
# Entr�e :
#   - param�tres :
#	- var : variable du formulaire pour ce menu
#	- defval : valeur par d�faut
# Sortie :
#   - code HTML g�n�r�
#
# Historique :
#   2003/08/03 : pda : conception
#

proc ::webapp::form-hidden {var defval} {
    set v [::webapp::html-string $defval]
    return "<INPUT TYPE=HIDDEN NAME=\"$var\" VALUE=\"$v\">"
}

#
# G�n�ration d'un arbre interactif (avec Javascript)
#
# Entr�e :
#   - param�tres :
#	- id : id de l'�l�ment racine (tag html "ul") de l'arbre g�n�r�
#	- tree : arbre, au format :
#		{<code-html> <arbre-fils> <arbre-fils> ... <arbre-fils>}
#	    chaque <arbre-fils> pouvant �tre lui-m�me un arbre.
#	    Si un arbre n'a pas de racine unique, le <code-html> de la
#	    racine est vide, et chaque fils constitue une racine.
#	- expcoll : liste de deux textes � afficher (pour tout d�rouler
#	    et tout enrouler, dans l'ordre)
# Sortie :
#   - valeur de retour : liste contenant les �l�ments suivants :
#		{head1 head2 onload html}
#	o� :
#	- head1 : code HTML pr�t � �tre ins�r� dans l'en-t�te HTML
#		de la page. Ce code est toujours le m�me quel que
#		soit l'arbre (fonctions Javascript)
#	- head2 : code HTML pr�t � �tre ins�r� dans l'en-t�te HTML
#		de la page. Ce code est sp�cifique � l'arbre
#		(sp�cifications CSS d�pendant de l'id)
#	- onload : code Javascript pour l'�tat initial (enroul� ou d�roul�)
#		initial de l'arbre
#	- html : code HTML pour l'arbre lui-m�me
#
# Exemple d'arbre :
#	{/
#	    {/bin
#		ls sh rm mkdir rmdir }
#	    {/etc passwd
#		{/etc/mail sendmail.cf submit.cf}}
#	    {/usr
#		{/usr/include
#		    {/usr/include/sys types.h}
#		    stdio.h}
#		{/usr/bin ...}
#	    }
#	}
#
# Historique :
#   2008/06/12 : pda/jean : conception
#   2008/08/14 : pda      : ajout expcoll
#

proc ::webapp::interactive-tree {id tree expcoll} {
    set root      [lindex $tree 0]
    set children  [lreplace $tree 0 0]
    set nchildren [llength $children]

    #
    # G�n�rer le code HTML non sp�cifique de l'en-t�te
    #

    set head1 $::webapp::treejs
    regsub -all "%TREEIMAGES%" $head1 $::webapp::treeimages head1

    #
    # G�n�rer le code HTML de l'en-t�te sp�cifique � cet arbre
    #

    set head2 $::webapp::treecss
    regsub -all "%ID%" $head2 $id head2
    regsub -all "%TREEIMAGES%" $head2 $::webapp::treeimages head2

    #
    # G�n�rer le code Javascript du "body onload"
    #

    set onload "javascript:multide('$id','none');"

    #
    # G�n�rer le code HTML de l'arbre
    #

    if {$root eq ""} then {
	set li ""
	for {set i 0} {$i < $nchildren} {incr i} {
	    set lastnext [expr {$i == $nchildren-1}]
	    append li [::webapp::interactive-tree-rec 1 \
						      [lindex $children $i] \
						      $lastnext \
						      ]
	    append li "\n"
	}
    } else {
	set li [::webapp::interactive-tree-rec 1 $tree 1]
    }
    set ul [helem ul $li "id" $id]

    #
    # Afficher les boutons "tout enrouler" et "tout d�rouler"
    #

    if {[llength $expcoll] > 0} then {
	set de [lindex $expcoll 0]
	set en [lindex $expcoll 1]

	set i1 [helem "img" "" \
			    "src" "$::webapp::treeimages/tree-plus-only.png" \
			    "alt" "+" \
			    "onclick" "multide('$id', 'block')" \
			    "class" "click" \
			]
	set i2 [helem "img" "" \
			    "src" "$::webapp::treeimages/tree-minus-only.png" \
			    "alt" "+" \
			    "onclick" "multide('$id', 'none')" \
			    "class" "click" \
			]
	set ul "$i1 $de &nbsp;&nbsp;&nbsp; $i2 $en\n$ul"
    }

    #
    # R�sultat final : assemblage des quatre �l�ments
    #

    return [list $head1 $head2 $onload $ul]
}

# level : profondeur (1 .. n) de l'arbre en cours
# tree : arbre en cours
# last : 1 si l'arbre est le dernier des fils de l'arbre p�re
proc ::webapp::interactive-tree-rec {level tree last} {
    set root [lindex $tree 0]
    set children [lreplace $tree 0 0]
    set nchildren [llength $children]

    if {$nchildren == 0} then {
	if {$last} then {
	    set file "$::webapp::treeimages/tree-joinbottom.gif"
	} else {
	    set file "$::webapp::treeimages/tree-join.gif"
	}
	set img [helem "img" "" src $file]
	set li [helem "li" "$img\n$root\n"]
    } else {
	set img [helem "img" "" \
				"src" "$::webapp::treeimages/tree-plus.gif" \
				"alt" "+" \
				"onclick" "de(this)" \
				"class" "click" \
			    ]

	set li ""
	for {set i 0} {$i < $nchildren} {incr i} {
	    set lastnext [expr {$i == $nchildren-1}]
	    append li [::webapp::interactive-tree-rec [expr $level+1] \
						      [lindex $children $i] \
						      $lastnext \
						      ]
	    append li "\n"
	}
	set class "niv$level"
	if {$last} then {
	    append class " last"
	}
	set ul [helem "ul" $li "class" $class]

	set li [helem "li" "$img\n$root\n$ul\n"]
    }

    return $li
}


##############################################################################
# Cacher des param�tres dans une liste de champs INPUT HIDDEN
##############################################################################

#
# Cache des param�tres dans une liste de champs INPUT HIDDEN
#
# Entr�e :
#   - param�tres : 
#	- champs : liste de champs � chercher dans le tableau
#	- formtab : tableau de champs tels qu'issu de get-data
# Sortie :
#   - valeur de retour : une suite de balises INPUT
#
# Historique
#   1999/11/01 : pda : conception et codage
#   2000/07/25 : pda : ajout de \n entre deux HIDDEN
#   2006/11/02 : pda : re-ajout de \n entre deux HIDDEN
#

proc ::webapp::cacher-parametres {champs formtab} {
    upvar $formtab ftab

    return [::webapp::hide-parameters $champs ftab]
}

proc ::webapp::hide-parameters {champs formtab} {
    upvar $formtab ftab

    set html {}
    foreach regexp $champs {
	foreach c [array names ftab] {
	    if {! [info exists dejavu($c)] && [regexp "^$regexp\$" $c]} then {
		set dejavu($c) 1
		foreach v $ftab($c) {
		    lappend html [::webapp::form-hidden $c $v]
		}
	    }
	}
    }
    return [join $html "\n"]
}

##############################################################################
# Appel d'un autre script cgi
##############################################################################

#
# Appelle un script CGI en respectant le protocole.
#
# Entr�e :
#   - param�tres :
#	- formtab : tableau, pass� par r�f�rence, contenant les champs
#		de formulaire, tels que get-data les extrait
#
# Sortie :
#   - valeur de retour : aucune
#   - sortie standard : les donn�es du script appel�es sont envoy�es sur stdout
#
# Notes : les variables d'environnement suivantes sont modifi�es
#   - REQUEST_METHOD : mis � GET
#   - PATH_INFO : remis � ""
#   - QUERY_STRING : la partie apr�s le "?" dans l'URL
#   Les autres variables ne sont pas chang�es.
#
# Historique :
#   2003/06/07 : pda : conception et codage
#

proc ::webapp::call-cgi {script formtab} {
    global env

    upvar $formtab ftab

    #
    # On utilise la m�thode "GET"
    #

    set env(REQUEST_METHOD) "GET"

    #
    # Positionner la "query string" en fonction des param�tres
    #

    set query {}
    foreach key [array names ftab] {
	set qkey [::webapp::post-string $key]
	foreach val $ftab($key) {
	    set qval [::webapp::post-string $val]
	    lappend query "$qkey=$qval"
	}
    }
    set env(QUERY_STRING) [join $query "&"]

    #
    #  D�truit PATH_INFO
    #

    catch {unset env(PATH_INFO)}

    #
    # Appeler le script
    #

    return [exec $script]
}

##############################################################################
# Traitement des formulaires
##############################################################################

#
# R�cup�re le contenu d'une FORM, ou de QUERY_STRING ou de PATH_INFO
# et place dans le tableau fourni en param�tre les champs trouv�s.
#
# Entr�e :
#   - param�tres :
#	- formtab : tableau, pass� par r�f�rence
#	- param : liste des param�tres des champs, sous la forme
#		d'une liste {champ nbmin nbmax def}, avec :
#			champ : nom du champ (regexp)
#			nbmin/mbmax : nb d'occurrences du champ (si checkbox)
#			def : valeur par d�faut
#   - variables d'environnement :
#	- CONTENT_TYPE : doit �tre "application/x-www-form-urlencoded"
#	- REQUEST_METHOD : doit �tre POST
#	- CONTENT_LENGTH : longueur des donn�es du formulaire
#	- PATH_INFO : la partie d'URL apr�s le nom du script CGI
#	- QUERY_STRING : la partie apr�s le "?" dans l'URL
# Sortie :
#   - param�tre formtab : chaque champ du formulaire est plac�
#	dans le tableau, avec comme index l'intitul� du champ
#   - valeur de retour : {} si erreur, liste des champs lus si pas d'erreur
#
# Historique :
#   1994/08/xx : pda : conception et codage
#   1999/02/25 : pda : documentation
#   1999/02/26 : pda : changement du test de CONTENT_TYPE (peut �tre vide)
#   1999/04/05 : pda : possibilit� d'avoir plusieurs fois le m�me champ
#   1999/04/05 : pda : ajout de la v�rification des champs
#   1999/10/02 : pda : gestion de plusieurs sources (pathinfo et querystring)
#   1999/10/29 : pda : traitement des noms de champs comme des regexp
#   1999/11/01 : pda : possibilit� de multiples appels et chgt valeur de retour
#

set ::webapp::gotform 0

proc ::webapp::get-data {formtab param} {
    global ::webapp::gotform

    upvar $formtab tab

    if {! $::webapp::gotform} then {
	#
	# On n'essayera plus de relire les param�tres (�a serait bloquant
	# si on essayait de relire sur stdin) lors des appels ult�rieurs.
	#

	set ::webapp::gotform 1

	#
	# R�cup�rer les informations de :
	#	- PATH_INFO
	#	- QUERY_STRING
	#	- les champs du formulaire
	#

	set lus 0
	incr lus [::webapp::recuperer-pathinfo    tab $param]
	incr lus [::webapp::recuperer-querystring tab $param]
	incr lus [::webapp::recuperer-form        tab $param]

	#
	# Si on n'a rien lu, il n'y a rien � v�rifier
	#

	if {$lus == 0} then {
	    return {}
	}
    }

    #
    # Boucle de v�rification : analyser tous les champs
    # list�s en param�tre.
    # En passant, on met specfield(champ) � 1 pour chaque champ
    # trouv� dans le formulaire.
    #

    foreach p $param {
	set nom   [lindex $p 0]
	set nbmin [lindex $p 1]
	set nbmax [lindex $p 2]
	set def   [lindex $p 3]
	if {[info exists tab($nom)]} then {
	    if {[::webapp::trouve-form tab $nom $nbmin $nbmax] == 0} then {
		return {}
	    }
	    set specfield($nom) 1
	} else {
	    set trouve 0
	    foreach p [array names tab] {
		if {[regexp "^$nom\$" $p]} then {
		    if {[::webapp::trouve-form tab $p $nbmin $nbmax] == 0} then {
			return {}
		    }
		    set specfield($p) 1
		    set trouve 1
		}
	    }

	    if {! $trouve} then {
		if {$nbmin > 0} then {
		    set tab(_error) "mandatory field '$nom' not found"
		    return {}
		} else {
		    set tab($nom) $def
		    set specfield($nom) 1
		}
	    }
	}
    }

    #
    # On renvoie maintenant la liste des �l�ments trouv�s
    #

    return [array names specfield]
}

proc ::webapp::trouve-form {formtab nom nbmin nbmax} {
    upvar $formtab tab
    set n [llength $tab($nom)]
    if {$n < $nbmin || $n > $nbmax} then {
	set tab(_error) "invalid number of fields ($n) for parameter '$nom'"
	return 0
    }
}

proc ::webapp::get-keyval {formtab l} {
    upvar $formtab tab

    foreach arg $l {
	if {[regexp {^([^=]+)=(.*)$} $arg bidon key val]} then {
	    set key [::webapp::unpost-string $key]
	    set val [::webapp::unpost-string $val]
	    lappend tab($key) $val
	}
    }
}

proc ::webapp::recuperer-pathinfo {formtab param} {
    upvar $formtab tab

    set lcomposants [::webapp::pathinfo]

    if {[llength $lcomposants] == 0} then {
	return 0
    }

    ::webapp::get-keyval tab $lcomposants

    return 1
}

proc ::webapp::recuperer-querystring {formtab param} {
    global env
    upvar $formtab tab

    if {! [info exists env(QUERY_STRING)]} then {
	return 0
    }

    ::webapp::get-keyval tab [split $env(QUERY_STRING) "&"]

    return 1
}

#
# D�code les �l�ments d'un formulaire en format "x-www-form-urlencoded"
#
# Entr�e :
#   - param�tres : 
#	- formtab : tableau de champs, cf get-data
# Sortie :
#   - valeur de retour : 1 si ok, 0 si erreur
#
# Historique
#   2003/06/01 : pda : s�paration de recuperer-form
#

proc ::webapp::x-www-form-urlencoded {formtab} {
    global env
    upvar $formtab tab

    #
    # M�thode classique pour r�cup�rer les champs
    # des formulaires
    #

    if {! [info exists env(CONTENT_LENGTH)]} then {
	lappend tab(_error) "non existant CONTENT_LENGTH"
	return 0
    }
    set line [read stdin $env(CONTENT_LENGTH)]

    ::webapp::get-keyval tab [split $line "&"]

    return 1
}

#
# D�code une sous-partie MIME d'un formulaire en format "form-data"
#
# Entr�e :
#   - param�tres : 
#	- formtab : tableau de champs, cf get-data
#	- entete : l'en-t�te de la sous-partie
#	- corps : le corps de la sous-partie
# Sortie :
#   - valeur de retour : 1 si ok, 0 si erreur
#
# Notes :
#   - le format de l'en-t�te de la sous-partie est :
#	Content-Disposition: form-data; name="<champ formulaire>"; filename="..."
#	Content-Type: image/gif
#   - le corps est le contenu du fichier.
#   - si c'est une variable classique de formulaire, il n'y a pas de filename=
#
# Historique
#   2003/06/01 : pda : commentaires
#

proc ::webapp::get-mime-part {formtab entete corps} {
    upvar $formtab tab

    set hdrre {^([^: \t]+):[ \t]*(.*)}
    set subhdrre {^([^= \t]+)[ \t]*=[ \t]*(.*)}
    set unquotere {^"([^"]*)"$}

    #
    # Traitement de l'en-t�te
    #

    regsub -all -- "\r\n" $entete "\n" entete
    foreach ligne [split $entete "\n"] {
	#
	# Premi�re partie : s�parer "nom: valeur" (ex: Content-Disposition: ...)
	#
	if {! [regexp $hdrre $ligne bidon hname hval]} then {
	    return 0
	}
	# nom du champ d'en-t�te
	set hname [string tolower $hname]

	# la valeur peut elle-m�me �tre de la forme "val;clef=val;clef=val..."
	set hval [split $hval ";"]

	set subhdrlist {}
	lappend subhdrlist VALEUR
	lappend subhdrlist [lindex $hval 0]

	#
	# Parcourir toutes les sous-valeurs de la ligne d'en-t�te
	#

	foreach hv [lrange $hval 1 end] {
	    if {! [regexp $subhdrre [string trim $hv] bidon clef val]} then {
		lappend tab(_error) "Invalid form-data sub-header name '$hname'"
		return 0
	    }
	    if {[regexp $unquotere $val bidon v]} then {
		set val $v
	    }
	    lappend subhdrlist [string tolower $clef]
	    lappend subhdrlist $val
	}
	array set sh $subhdrlist

	#
	# Une fois la ligne d'en-t�te compl�tement parcourue, regarder
	# quels sont les associations "clef/valeur" obtenues.
	# Ces associations sont dans le tableau sh()
	#	sh(VALEUR) :	valeur du champ d'en-t�te
	#	sh(name) :	nom de la variable du formulaire
	#	sh(filename) :	nom du fichier fourni par le client
	#

	switch -- $hname {
	    content-disposition {
		if {! [string equal -nocase $sh(VALEUR) "form-data"]} then {
		    lappend tab(_error) "Invalid Content-Disposition header"
		    return 0
		}
		if {! [info exists sh(name)]} then {
		    lappend tab(_error) "No 'name' attribute in form"
		    return 0
		}
		set h(name) $sh(name)
		if {[info exists sh(filename)]} then {
		    set h(filename) $sh(filename)
		}
	    }
	    content-type {
		set h(contenttype) $sh(VALEUR)
	    }
	    default {
		lappend tab(_error) "Invalid form-data sub-header name '$hname'"
		return 0
	    }
	}
	unset sh
    }

    #
    # Traitement du corps
    #

    if {! [info exists h(name)]} then {
	lappend tab(_error) "No 'name' attribute in form"
	return 0
    }
    set name $h(name)

    #
    # Si c'est un fichier, le placer dans une liste de la forme
    #		{file <type> <filename> <content>}
    # Sinon, nettoyer les \r\n
    #

    if {[info exists h(filename)]} then {
	if {! [info exists h(contenttype)]} then {
	    set h(contenttype) application/octet-stream
	}

	lappend tab($name) [list "file" $sh(filename) $h(contentype) $corps]

    } else {
	#
	# Variable classique (i.e. pas un fichier)
	#
	regsub -all -- "\r\n" $corps "\n" corps
	lappend tab($name) $corps
    }

    return 1
}

proc ::webapp::form-data {formtab contenttype} {
    global env
    upvar $formtab tab

    #
    # M�thode pour r�cup�rer les champs des formulaires
    # sp�cifi�e dans la RFC 1867, notamment pour g�rer
    # les fichiers.
    #

    if {! [info exists env(CONTENT_LENGTH)]} then {
	lappend tab(_error) "non existant CONTENT_LENGTH"
	return 0
    }

    #
    # Extraire le d�limiteur
    #

    set boundary ""
    foreach element [split $contenttype ";"] {
	if {[regexp {boundary=(.*)} $element bidon boundary]} then {
	    break
	}
    }
    if {[string equal $boundary ""]} then {
	lappend tab(_error) "boundary not found in CONTENT_TYPE"
	return 0
    }
    set boundary "--$boundary"

    #
    # Lire les donn�es du formulaire et les mettre en m�moire
    #

    fconfigure stdin -translation binary
    set line [read stdin $env(CONTENT_LENGTH)]

    set fd [open /tmp/g.log w]
    fconfigure $fd -translation binary
    puts $fd $line
    close $fd

    #
    # Rechercher le premier d�limiteur
    #

    set offset [string first $boundary $line 0]
    if {$offset == -1} then {
	lappend tab(_error) "Invalid form-data encoding (no first boundary)"
	return 0
    }
    set blen [string length $boundary]

    incr offset $blen

    #
    # Invariants de boucle
    #  - offset = indice juste apr�s le d�limiteur (qui correspond soit �
    #			"\r\n", soit � "--\r\n" si c'est le dernier)
    #  - retval = 1 si aucune erreur ne s'est produite
    #
    #

    set retval 1
    while {[set next [string first $boundary $line $offset]] != -1} {
	# - next = indice du d�limiteur suivant

	#
	# Arr�t si le premier d�limiteur correspond � une fin
	# d'arguments. Ce cas ne devrait jamais arriver, mais
	# il vaut mieux pr�voir l'impossible...
	#

	if {[string equal [string range $line $offset [expr $offset+1]] "--"]} then {
	    break
	}

	# on saute le \r\n
	incr offset 2

	#
	# S�paration de l'en-t�te et du corps
	#

	set sephdr [string first "\r\n\r\n" $line $offset]
	set entete [string range $line $offset [expr $sephdr-1]]

	set r [::webapp::get-mime-part tab \
			[string range $line $offset [expr $sephdr-1]] \
			[string range $line [expr $sephdr+4] [expr $next-3]] \
		    ]
	if {$r == 0} then {
	    lappend tab(_error) "Invalid form-data encoding of subpart"
	    set retval 0
	}

	set offset [expr $next + $blen]
    }

    return $retval
}

proc ::webapp::recuperer-form {formtab param} {
    global env
    upvar $formtab tab

    if {! [info exists env(REQUEST_METHOD)]} then {
	lappend tab(_error) "non existant REQUEST_METHOD"
	return 0
    }
    if {! [string equal $env(REQUEST_METHOD) "POST"]} then {
	lappend tab(_error) "invalid method '$env(REQUEST_METHOD)'"
	return 0
    }

    #
    # Traitement de content-type
    #

    if {[info exists env(CONTENT_TYPE)]} then {
	set type $env(CONTENT_TYPE)
    } else {
	#
	# Cas particulier du browser de KDE 1 : si
	# CONTENT_TYPE est vide, c'est implicitement
	# "application/x-www-form-urlencoded".
	#
	set type application/x-www-form-urlencoded
    }

    switch -glob -- $type {
	application/x-www-form-urlencoded	{
	    set r [::webapp::x-www-form-urlencoded tab]
	}
	multipart/form-data* {
	    set r [::webapp::form-data tab $type]
	}
	default {
	    lappend tab(_error) "invalid CONTENT_TYPE '$env(CONTENT_TYPE)'"
	    set r 0
	}
    }

    #
    # On a lu quelque chose
    #

    return $r
}

#
# Convertit une cha�ne (donn�es d'un formulaire) en caract�res
# "normaux"
#
# Entr�e :
#   - param�tres :
#	- str : la cha�ne � convertir
# Sortie :
#   - valeur de retour : la cha�ne convertie
#
# Historique
#   1994/08/xx : pda : conception et codage
#   1999/02/25 : pda : documentation
#   2001/02/28 : pda : remplacement des \r\n par \n
#

proc ::webapp::unpost-string {str} {
    #
    # Remplace tous les espaces
    #
    regsub -all "\\+" $str " " str

    #
    # Remplace tous les %xx par le caract�re correspondant
    #
    set l   [split $str "%"]
    set new [lindex $l 0]

    foreach p [lrange $l 1 end] {
	set c1 [hexchar [string range $p 0 0]]
	set c2 [hexchar [string range $p 1 1]]
	if {$c1 != -1 && $c2 != -1} then {
	    set v [expr "($c1*16)+$c2"]
	    set r [string range $p 2 end]
	    append new [format "%c%s" $v $r]
	} else {
	    append new "%$p"
	}
    }

    #
    # Nettoyage des mauvais caract�res de fin de ligne
    #
    regsub -all -- "\r\n" $new "\n" new
    regsub -all -- "\r" $new "\n" new

    return $new
}

proc ::webapp::hexchar {c} {
    if {[scan $c "%x" c] == 0} then {
	set c -1
    }
    return $c
}

#
# Convertit une cha�ne contenant �ventuellement des caract�res sp�ciaux
# HTML en cha�ne dans laquelle les caract�res sp�ciaux sont remplac�s
# par des caract�res "%.."
#
# Entr�e :
#   - param�tres :
#	- str : la cha�ne � convertir
# Sortie :
#   - valeur de retour : la cha�ne convertie
#
# Historique
#   1999/11/01 : pda : conception
#

proc ::webapp::post-string {str} {
    #
    # Remplace tous les caract�res sp�ciaux
    #
    regsub -all {%}  $str "%25" str
    regsub -all {\+} $str "%2B" str
    regsub -all {\&} $str "%26" str
    regsub -all "\n" $str "%0A" str
    regsub -all "\r" $str "%0D" str
    regsub -all {\<} $str "%3C" str
    regsub -all {=}  $str "%3D" str
    regsub -all {\>} $str "%3E" str
    regsub -all {\?} $str "%3F" str
    regsub -all {"}  $str "%22" str
    regsub -all {"}  $str "%22" str
    regsub -all { }  $str "%20" str

    return $str
}

#
# Convertit une cha�ne contenant �ventuellement des caract�res sp�ciaux
# HTML en cha�ne dans laquelle les caract�res sp�ciaux sont remplac�s
# par des caract�res "&...;"
#
# Entr�e :
#   - param�tres :
#	- str : la cha�ne � convertir
# Sortie :
#   - valeur de retour : la cha�ne convertie
#
# Historique
#   1999/11/02 : pda : conception
#

proc ::webapp::html-string {str} {
    #
    # Remplace tous les caract�res sp�ciaux
    #
    regsub -all {\&} $str {\&amp;} str
    regsub -all {\<} $str {\&lt;} str
    regsub -all {\>} $str {\&gt;} str
    regsub -all {"}  $str {\&quot;} str

    return $str
}

#
# Importe les champs de formulaire dans des variables individuelles
#
# Entr�e :
#   - param�tres :
#	- formtab : tableau, pass� par r�f�rence, contenant les valeurs
#	    des param�tres fournis au formulaire
# Sortie :
#   - variables nomm�es par formtab : initialis�es
#   - valeur de retour : aucune
#
# Historique :
#   2006/08/29 : pda : conception et codage
#

proc ::webapp::import-vars {formtab} {
    upvar $formtab tab

    foreach varname [array names tab] {
	upvar $varname var
	set var $tab($varname)
    }
}

##############################################################################
# Mail et adresses �lectroniques
##############################################################################

#
# V�rifie si une adresse �lectronique est valide,
# c'est � dire si elle v�rifie les conditions suivantes :
# - pr�sence de "@"
# - absence d'espace et de tabulations
#
# Entr�e :
#   - param�tres : 
#	- email : adresse �lectronique telle que saisie par l'utilisateur
# Sortie :
#   - valeur de retour : 0 (adresse incorrecte) ou 1 (adresse correcte)
#
# Historique
#   1994/08/xx : pda : conception et codage
#   1999/02/25 : pda : documentation
#

proc ::webapp::valid-email {email} {
    set email [string trim $email]

    if {[string first "@" $email] == -1} then { return 0 }
    if {[string first " " $email] != -1} then { return 0 }
    if {[string first "\t" $email] != -1} then { return 0 }
    return 1
}

#
# Envoi d'un mail
#
# Entr�e :
#   - param�tres :
#	- from : l'�metteur
#	- replyto : le destinataire des r�ponses
#	- to : le ou les destinataires
#	- cc : le ou les destinataires, si besoin est
#	- bcc : destinataire cach�, si besoin est
#	- subject : le sujet
#	- texte : le texte
#	- type : le type du mail, par d�faut 'text/plain; charset="iso8859-15"'
#
# Sortie :
#   - valeur de retour : aucune
#
# Historique :
#   2003/09/29 : pda : conception et codage
#   2009/02/23 : pda : ajout param�tre optionnel type
#

proc ::webapp::mail {from replyto to cc bcc subject texte {type {}}} {
    set fd [open "|$::webapp::sendmail" "w"]

    set to [join $to ", "]
    puts $fd "From: $from"
    puts $fd "To: $to"

    if {! [string equal $cc ""]} then {
	puts $fd "Cc: $cc"
    }
    if {! [string equal $bcc ""]} then {
	puts $fd "Bcc: $bcc"
    }
    if {! [string equal $replyto ""]} then {
	puts $fd "Reply-to: $replyto"
    }
    if {[string equal $type ""]} then {
	set type {text/plain; charset="iso-8859-15"}
    }
    puts $fd "Subject: $subject"
    puts $fd "Mime-Version: 1.0"
    puts $fd "Content-Type: $type"
    puts $fd "Content-Transfer-Encoding: 8bit"
    puts $fd ""
    puts $fd $texte
    close $fd
}

##############################################################################
# G�n�ration d'une page HTML par substitution dans une page existante
##############################################################################

#
# Substitue, dans un fichier, des motifs par des valeurs calcul�es
# par le script CGI.
#
# Entr�e :
#   - param�tres : 
#	- fichier : le nom du fichier servant de base pour la substitution
#	- subst : liste de susbtitutions, de la forme 
#		{{motif valeur} {motif valeur} ...}
# Sortie :
#   - valeur de retour : le fichier susbtitu�
#
# Historique
#   1999/03/25 : pda : conception et codage
#   1999/11/02 : pda : suppression de & comme caract�re sp�cial
#   2002/05/12 : pda : suppression de \ comme caract�re sp�cial
#

proc ::webapp::file-subst {fichier subst} {
    return [::webapp::substituer $fichier $subst]
}

proc ::webapp::substituer {fichier subst} {
    set fd [open $fichier r]
    set string [read $fd]
    close $fd

    foreach l $subst {
	set motif  [lindex $l 0]
	set valeur [lindex $l 1]

	regsub -all {\\} $valeur {\\&} valeur
	regsub -all {\&} $valeur {\\&} valeur

	regsub -all -- $motif $string $valeur string
    }
    return $string
}

##############################################################################
# Gestion des sessions
##############################################################################

#
# R�cup�re une cha�ne al�atoire (ou pseudo-al�atoire)
#
# Entr�e :
#   - param�tres : -
# Sortie :
#   - valeur de retour : une cha�ne de 20 chiffres
#
# Historique
#   1999/07/14 : pda : conception
#

proc ::webapp::random {} {
    set rand ""

    append rand [format "%03d" [expr [clock clicks] % 1000]]
    # rand contains now 3 digits

    append rand [format "%05d" [pid]]
    # rand contains now 8 digits

    # %d = day of month 01..31
    # %H = hour 00..23
    # %j = day of the year 001..366
    # %M = minute 00..59
    # %S = second 00..59
    # %w = weekday 0..6
    append rand [clock format [clock seconds] -format "%d%H%j%M%S%w"]
    # rand contains now 20 digits

    return $rand
}

##############################################################################
# Sortie d'une page Web ou autre
##############################################################################

#
# Sort une page Web ou autre
#
# Entr�e :
#   - param�tres :
#	- type : le type de sortie, html ou pdf
#	- page : la page (en html si html, en latex si pdf)
#	- fichier : nom de fichier � renvoyer
# Sortie :   
#   - envoi direct sur la sortie standard
#
# Historique
#   2002/05/20 : pda : conception
#   2002/06/21 : pda : ajout de types
#   2002/10/24 : pda : ajout de la sortie csv
#   2008/02/27 : jean/zamboni : gestion des extensions de nom de fichiers
#

proc ::webapp::send {type page {fichier "output"}} {
    #
    # D�termine l'extension du fichier
    #
    switch -- $type {
	rawpdf	{ set ext "pdf" }
	jpeg 	{ set ext "jpg" }
	default { set ext $type }
    }
    
    #
    # on rajoute une extension au nom de fichier si necessaire
    #
    if {! [regexp "\.$ext\$" $fichier] } then {
	append fichier "." $ext
    }

    switch -- $type {
	html 	{ ::webapp::sortie-html $page }
	csv	{ ::webapp::sortie-csv $page $fichier }
	png 	{ ::webapp::sortie-bin image/png $page $fichier }
	gif 	{ ::webapp::sortie-bin image/gif $page $fichier }
	jpeg 	{ ::webapp::sortie-bin image/jpeg $page $fichier }
	rawpdf 	{ ::webapp::sortie-bin application/pdf $page $fichier }
	pdf 	{ ::webapp::sortie-latex $page $fichier }
    }
}

#
# Sort une page Web ou autre
#
# Entr�e :
#   - param�tres :
#	- page : la page HTML, sans le content-type
# Sortie :   
#   - envoi direct sur la sortie standard
#
# Historique
#   2001/10/20 : pda : conception et codage
#

proc ::webapp::sortie-html {page} {
    puts stdout "Content-type: text/html"
    puts stdout ""
    puts stdout $page
}

#
# Sort un fichier CSV
#
# Entr�e :
#   - param�tres :
#	- page : le fichier CSV, sans le content-type
#	- fichier : nom de fichier � renvoyer
# Sortie :   
#   - envoi direct sur la sortie standard
#
# Historique
#   2002/10/24 : pda : conception et codage
#   2008/02/27 : jean/zamboni : Content-type et filename
#

proc ::webapp::sortie-csv {page fichier} {
    puts stdout "Content-type: text/csv"
    puts stdout "Content-Disposition: attachment; filename=$fichier"
    puts stdout ""
    puts stdout $page
}

#
# Sort un document binaire
#
# Entr�e :
#   - param�tres :
#	- type : type MIME
#	- page : le fichier
#	- fichier : nom de fichier � renvoyer
# Sortie :   
#   - envoi direct sur la sortie standard
#
# Historique
#   2002/05/21 : pda : conception et codage
#   2008/02/27 : jean/zamboni : ajout filename
#

proc ::webapp::sortie-bin {type page fichier} {
    puts stdout "Content-type: $type"
    puts stdout "Content-Disposition: attachment; filename=$fichier"
    puts stdout ""
    flush stdout
    fconfigure stdout -translation binary
    puts -nonewline stdout $page
}


#
# Sort un document latex compil� en pdf
#
# Entr�e :
#   - param�tres :
#	- page : le source latex, pr�t � �tre compil�
#	- fichier : nom de fichier � renvoyer
#   - variable globale debuginfos : valeur latexfiles
# Sortie :   
#   - envoi direct sur la sortie standard
#
# Historique
#   2002/05/11 : pda : conception et codage
#   2002/05/12 : pda : ajout de debuginfos
#   2008/02/27 : jean/zamboni : ajout filename
#

proc ::webapp::sortie-latex {page fichier} {
    global errorInfo

    if {[lsearch $::webapp::debuginfos latexsource] != -1} then {
	::webapp::sortie-html \
	    "<PRE>$page</PRE>"
	return
    }

    #
    # Le changement de r�pertoire est n�cessaire car latex d�pose
    # des fichiers .aux, .log et .pdf dans le r�pertoire courant.
    #

    cd $::webapp::tmpdir

    #
    # Nommage des fichiers utilis�s. Le r�pertoire est absolu,
    # c'est plus clair dans les messages d'erreur.
    #

    set prefix $::webapp::tmpdir/arrgen[pid]
    set texfile "${prefix}.tex"
    set pdffile "${prefix}.pdf"
    set auxfile "${prefix}.aux"
    set logfile "${prefix}.log"

    #
    # Envoi du source latex dans le fichier
    #

    if {[catch {set fd [open $texfile "w"]} m]} then {
	::webapp::sortie-html \
	    "Impossible de cr�er '$texfile': <PRE>$errorInfo</PRE>"
	return
    }
    puts $fd $page
    close $fd

    #
    # G�n�ration du fichier pdf
    #

    if {[catch {set log [exec $::webapp::pdflatex $texfile]} msg]} then {
	::webapp::sortie-html \
	    "Impossible de g�n�rer '$pdffile': <PRE>$errorInfo</PRE>"
	return
    }

    #
    # Sortie du r�sultat
    #

    if {[catch {set fd [open $pdffile "r"]} m]} then {
	::webapp::sortie-html \
	    "Impossible de lire '$pdffile': <PRE>$errorInfo</PRE>"
	return
    }
    fconfigure $fd -translation binary
    set pdf [read $fd]
    close $fd

    puts stdout "Content-Type: application/pdf"
    puts stdout "Content-Disposition: attachment; filename=$fichier"
    puts stdout ""
    flush stdout
    fconfigure stdout -translation binary
    puts -nonewline stdout $pdf

    #
    # Effacement des fichiers temporaires
    #

    if {[lsearch $::webapp::debuginfos latexfiles] == -1} then {
	file delete -force -- $texfile $pdffile $auxfile $logfile
    }
}

##############################################################################
# Sortie des erreurs dans une belle page Web
##############################################################################

#
# Sortie des erreurs dans une belle page Web
#
# Entr�e :
#   - param�tres :
#	- page : fichier contenant la page HTML � trous
#	- msg : le message d'erreur
# Sortie : pas de sortie, la proc�dure fait un exit.
#
# Historique
#   2000/07/26 : pda     : conception
#   2000/07/27 : pda     : documentation
#   2001/10/20 : pda     : utilisation de la proc�dure de sortie
#   2002/12/26 : pda     : mise en package
#   2003/12/11 : pda     : ajout du traitement de \n
#

proc ::webapp::error-exit {page msg} {
    set msg [::webapp::html-string $msg]
    regsub -all "\n" $msg "<br>" msg
    ::webapp::send html [::webapp::file-subst $page \
				    [list [list %MESSAGE% $msg] \
					] \
				]
    exit 0
}

##############################################################################
# Des fois, il faut bien avoir recours aux derni�res extr�mit�s...
##############################################################################

#
# Affiche tous les param�tres fournis au script CGI.
#
# Entr�e : tout l'environnement d'un script CGI
# Sortie :
#   - envoi direct
#
# Historique
#   1999/03/25 : pda : conception et codage
#

proc ::webapp::cgidebug {} {
    global env argv

    puts "Content-type: text/html"
    puts ""

    puts "<TITLE>Debug information</TITLE>"
    puts "<H1>Debug information</H1>"

    set pwd [exec pwd]  
    puts "Working directory = $pwd <P>"

    puts "Parameters : <P>"
    set n 0
    puts "<UL>"
    foreach i $argv {
	incr n
	puts "<LI> arg $n = /$i/"
    }
    puts "</UL>"

    puts "Environment : <P>"
    puts "<UL>"
    foreach i [lsort [array names env]] {
	puts "<LI> $i=$env($i)"
    }
    puts "</UL>"

    if {[info exists env(CONTENT_LENGTH)]} then {
	puts "Standard input : <P>"  
	puts "<CODE>"
	puts [read stdin $env(CONTENT_LENGTH)]
	puts "</CODE>"
    }
}

##############################################################################
# Prot�ger l'acc�s � des applications
##############################################################################

#
# Teste l'existence d'un fichier et interdit l'acc�s �
# l'application si le fichier existe.
#
# Entr�e :
#   - param�tres :
#	- ftest : fichier � tester, contenant le message d'interdiction
#	- lusers : liste d'utilisateurs autoris�s � acc�der quand m�me
#	- ferr : fichier HTML � trou (%MESSAGE% = message d'interdiction)
#   - variables d'environnement :
#	- REMOTE_USER : une cha�ne de la forme "login""
# Sortie :
#   - envoi direct, ou rien du tout
#
# Historique
#   1999/03/25 : pda : conception et codage
#   1999/06/21 : pda : fin de la conception
#

proc ::webapp::nologin {ftest lusers ferr} {
    set user [::webapp::user]
    if {[file exists $ftest]} then {
	if {[string equal $user ""] || [lsearch -exact $lusers $user] == -1} then {
	    set fd [open $ftest r]
	    set message [read $fd]
	    close $fd

	    ::webapp::send html [::webapp::file-subst $ferr \
					[list \
						[list %MESSAGE% $message] \
					    ] \
				    ]
	    exit 0
	}
    }
}

##############################################################################
# Une interface agr�able pour la programmation des scripts CGI
##############################################################################

proc ::webapp::cgi-env {} {
}

proc ::webapp::cgi-get {} {
}

proc ::webapp::cgi-err {msg debug} {
    global argv

    set script [::webapp::script-name]
    set date   [clock format [clock seconds]]

    set page ""
    append page "<HTML>\n"
    append page "<HEAD><TITLE>Erreur !</TITLE></HEAD>\n"
    append page "<BODY TEXT=#000000 BGCOLOR=#FFFFFF>\n"
    append page "<FONT FACE=\"Arial,Helvetica\">\n"
    append page "<H1>Probl�me !</H1>\n"

    if {$debug} then {
	set pwd    [exec pwd]  

	append page "Erreur d�tect�e dans l'ex�cution du script '$script'\n"
	append page "� '$date'&nbsp;:\n"
	append page "<HR>\n"
	append page "<PRE>[::webapp::html-string $msg]</PRE>\n"
	append page "<HR>\n"

	append page "<H2>Contexte</H2>\n"
	append page "R�pertoire = $pwd<P>\n"

	append page "Param�tres&nbsp;:<BR>\n"
	set n 0
	append page "<UL>\n"
	foreach i $argv {
	    incr n
	    append page "<LI> arg $n = /[::webapp::html-string $i]/\n"
	}
	append page "</UL>\n"

	append page "Environment&nbsp;:<BR>\n"
	append page "<UL>\n"
	foreach i [lsort [array names env]] {
	    append page "<LI> $i=[::webapp::html-string $env($i)]\n"
	}
	append page "</UL>\n"

	if {[info exists env(CONTENT_LENGTH)]} then {
	    append page "Standard input&nbsp;: <P>\n"
	    append page "<CODE>\n"
	    append page [::webapp::html-string [read stdin $env(CONTENT_LENGTH)]]
	    append page "</CODE>\n"
	}
    } else {
	append page "Probl�me d�tect� dans l'application&nbsp;:\n"
	append page "<UL>\n"
	append page "<LI> � '$date'\n"
	append page "<LI> dans le script '$script'\n"
	append page "</UL>\n"
	append page "Veuillez contacter l'administrateur du site\n"
	append page "et lui envoyer copie de ce message.\n"

	puts stderr "\[$date\] webapp/$script: $msg"
    }
    append page "</BODY></HTML>\n"

    ::webapp::send html $page
}

#
# Lance l'ex�cution d'un script CGI
#
# Entr�e :
#   - tout l'environnement d'un script CGI
#   - param�tres :
#	- script : nom du script � ex�cuter, avec param�tres �ventuels
#	- debug : 1 s'il faut sortir l'environnement, ou 0 pour un simple message
# Sortie :
#   - envoi direct
#
# Historique
#   2001/06/20 : pda : conception
#

proc ::webapp::cgi-exec {script {debug 0}} {
    global errorInfo

    ::webapp::cgi-env
    if [catch $script msg] then {
	# on n'utilise pas msg, car errorInfo le contient d�j�
	::webapp::cgi-err $errorInfo $debug
    }
    exit 0
}

#
# Classe "utilisateur dans la base d'authentification"
#
# Repr�sente les attributs d'un utilisateur tel qu'il est stock�
# dans la base d'authentification (PostgreSQL ou LDAP) sous une 
# forme unifi�e.
#
# Options :
#   aucune
#
# M�thodes
#   get	    : r�cup�re la valeur (unique) d'un attribut
#   set	    : modifie la valeur d'un attribut (en m�moire uniquement).
#	      C'est une m�thode utilis�e uniquement par la classe authbase
#   exists  : indique si l'utilisateur a �t� trouv� dans la base.
#
# Historique
#   2007/10/05 : pda/jean : int�gration et documentation
#

snit::type ::webapp::authuser {
    variable exists 0
    variable attrvals -array {}

    method exists {{value {}}} {
	if {$value ne ""} then {
	    set exists $value
	}
	return $exists
    }

    method get {attr} {
	if {[info exists attrvals($attr)]} then {
	    set v $attrvals($attr)
	} else {
	    set v ""
	}
	return $v
    }

    method set {attr val} {
	set attrvals($attr) $val
    }
}

#
# Classe "base d'authentification"
#
# Repr�sente une base d'authentification et donne les moyens 
# de r�cup�rer les attributs d'un utilisateur
#
# Options :
#   method  : "ldap" ou "postgresql"
#   db	    : param�tres d'acc�s � la base d'authentification (cf. ci-dessous)
#   attrmap : traduction d'attribut
#
# M�thodes
#   getuser : recherche l'utilisateur par son login et r�cup�re ses attributs
#
# Historique
#   2007/10/05 : pda/jean : int�gration et documentation
#

snit::type ::webapp::authbase {

    # Option method: ldap, postgresql
    option -method  -default "none"

    # Option db :
    #   pour ldap:
    #	  url ...
    #	  [ binddn ... ]
    #	  [ bindpw ... ]
    #	  base ...
    #	  searchuid ... (filtre avec un %s pour le login)
    #   pour postgresql:
    #	  host=...
    #	  dbname=...
    #	  user=...
    #	  password=...
    option -db      -default {}

    # Option attrmap :
    # liste de couples
    #	<nom dans ce module> <nom dans la base>
    option -attrmap -default {
	login    login
	password password
	nom      nom
	prenom   prenom
	mel      mel
	tel      tel
	mobile   mobile
	fax      fax
	adr      adr
    }

    variable connected "no"
    variable handle

    destructor {
	if {$connected} then {
	    Disconnect $selfns
	}
    }

    method getuser {login u} {
	if {! $connected} then {
	    Connect $selfns
	}

	$u exists 0
	set n 0

	switch $options(-method) {
	    postgresql {
		set qlogin [::pgsql::quote $login]
		set sql "SELECT * FROM utilisateurs WHERE login = '$qlogin'"
		set av {}
		pg_select $handle $sql tab {
		    set av [array get tab]
		    incr n
		}
	    }
	    ldap {
		array set dbopt $options(-db)
		set base   $dbopt(base)
		set search $dbopt(searchuid)

		# XXXXXXXXX  Il faut quoter le login
		set filter [format $search $login]

		set e [::ldapx::entry create %AUTO%]
		set n [$handle read $base $filter $e]

		set av {}
		if {$n == 1} then {
		    #
		    # On ne garde que la premi�re valeur des champs multivalu�s
		    #

		    array set x [$e getall]
		    foreach i [array names x] {
			set x($i) [lindex $x($i) 0]
		    }
		    set av [array get x]
		}

		$e destroy
	    }
	    default {
		error "Auth method '$options(-method)' not supported"
	    }
	}

	if {$av ne ""} then {
	    $u exists 1
	    array set t $av
	    foreach {cmod cbase} [string tolower $options(-attrmap)] {
		set v {}
		foreach c $cbase {
		    if {[info exists t($c)]} then {
			lappend v $t($c)
		    }
		    $u set $cmod [join $v ", "]
		}
	    }
	}

	return $n
    }

    proc Connect {selfns} {
	set db $options(-db)
	switch $options(-method) {
	    postgresql {
		if {[catch {set handle [pg_connect -conninfo $db]} msg]} then {
		    error $msg
		}
	    }
	    ldap {
		array set dbopt $db

		if {! [info exists dbopt(url)]} then {
		    error "url not configured for LDAP method"
		} else {
		    set url $dbopt(url)
		}
		if {[info exists dbopt(binddn)] && [info exists dbopt(bindpw)]} then {
		    set binddn $dbopt(binddn)
		    set bindpw $dbopt(bindpw)
		} else {
		    set binddn ""
		    set bindpw ""
		}

		set handle [::ldapx::ldap create %AUTO%]
		if {! [$handle connect $url $binddn $bindpw]} then {
		    error [$handle error]
		}
	    }
	    none {
		error "Auth method not configured"
	    }
	    default {
		error "Auth method '$options(-method)' not supported"
	    }
	}
	set connected 1
    }

    proc Disconnect {selfns} {
	switch $options(-method) {
	    postgresql {
		if {[catch {pg_disconnect $handle} msg]} then {
		    error $msg
		}
	    }
	    ldap {
		if {! [$handle disconnect]} then {
		    error [$handle error]
		}
		$handle destroy
	    }
	    default {
		error "Auth method '$options(-method)' not supported"
	    }
	}
	set connected 0
    }
}

#
# Classe "systeme de log"
#
# Repr�sente l'acces a un support de journaux
#
# Options :
#   method  : "postgresql", "file", "syslog"
#   medium  : param�tres 
#   subsys  : nom g�n�rique de l'application
#
# M�thodes
#   log     : �crit un �v�nement dans le journal
#
# Historique
#   2007/10/23 : pda/jean : int�gration et documentation
#

snit::type ::webapp::log {

    # method: postgresql, file, syslog
    option -method  -default "none"

    # medium for postgresql :
    #	host ...
    #	dbname ...
    #	table ...
    #	user ...
    #	password ...
    #   (table must contain the columns : date, subsys, event, login, ip, msg)
    # medium for opened-postgresql
    #   dbfd ...
    #   table ...
    # medium for file :
    #   file ...
    # medium for syslog :
    #   host ...
    #   facility ...
    #   priority ...
    option -medium      -default {}

    # subsystem
    option -subsys -default "none"

    variable handle ""
    variable table "log"

    constructor {args} {
	$self configurelist $args

	switch $options(-method) {
	    none {
		error "Wrong # args: should be -method ... -medium ..."
	    }
	    postgresql {
		array set x $options(-medium)
		set db {}
		foreach c {host dbname user password} {
		    if {[info exists x($c)]} then {
			lappend db "$c=$x($c)"
		    }
		}
		set db [join $db " "]
		if {[catch {set handle [pg_connect -conninfo $db]} msg]} then {
		    error "Cannot connect: $msg"
		}
		if {[info exists x(table)]} then {
		    set table $x(table)
		}
	    }
	    opened-postgresql {
		array set x $options(-medium)
		if {! [info exists x(db)]} then {
		    error "db is a mandatory parameter"
		}
		set db $x(db)
		if {[info exists x(table)]} then {
		    set table $x(table)
		}
	    }
	    file {
		# XXX
	    }
	    syslog {
		# XXX
	    }
	    default {
		error "Unknown method '$options(-method)'"
	    }
	}
    }
    
    destructor {
	switch $options(-method) {
	    postgresql {
		pg_disconnect $handle
	    }
	    file {
	    }
	    syslog {
	    }
	    default {
		error "Unknown method '$options(-method)'"
	    }
	}	
    }

    method log {date event login ip msg} {

	switch $options(-method) {
	    postgresql {
		foreach c {event login ip msg} {
		    if {[string equal [set $c] ""]} then {
			set t($c) NULL
		    } else {
			switch $c {
			    date {
				set t($c) "to_timestamp([set $c])"
			    }
			    default {
				set t($c) "'[::pgsql::quote [set $c]]'"
			    }
			}
		    }
		}
		if {[string equal $date ""]} then {
		    set datecol ""
		    set dateval ""
		} else {
		    set datecol "date,"
		    set dateval "to_timestamp($date),"
		}
		set t(subsys) "'[::pgsql::quote $options(-subsys)]'"
		set sql "INSERT INTO $table
				($datecol subsys, event, login, ip, msg)
			    VALUES (
				$dateval $t(subsys), $t(event), $t(login),
				    $t(ip), $t(msg))"
		if {! [::pgsql::execsql $handle $sql m]} then {
		    error "Cannot write log ($m)"
		}
	    }
	    file {
	    }
	    syslog {
	    }
	    default {
		error "Unknown method '$options(-method)'"
	    }
	}
    }
}
