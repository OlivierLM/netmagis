#  
# Librairie de fonctions TCL pour faciliter l'acc�s � l'annuaire LDAP
#
# Historique
#   2002/02/11 : pda : conception � partir de l'ancien annuaire CSI
#   2002/07/29 : pda : mise en service
#

#
# Ce package fournit les fonctions suivantes :
#
# ::annuaire::connect
#	connexion � la base annuaire
#
# ::annuaire::disconnect
#	d�connexion de la base annuaire
#
# ::annuaire::chercher-par-nom
#	recherche un nom, et renvoie une liste de listes de la forme
#		{{num_individu num_service titre}
#			nom pr�nom {liste des libell�s du service}
#			batiment etage bureau tel fax titre email web}
#
# ::annuaire::format-html
#	renvoie une entr�e de l'annuaire, telle que retourn�e par
#	chercher-par-nom, en format HTML
#

package provide annuaire 1.0
package require base64
package require arrgen

namespace eval annuaire {
    namespace export \
		connect disconnect \
		chercher-par-nom \
		format-html \
		ldapsearch

    #
    # Valeurs par d�faut
    #
    # Pour la commande de recherche ldap
    # 1 = uri
    # 2 = base-dn
    # 3 = limite
    # 4 = filtre
    # 5 = champs demand�s
    # 6 = options suppl�mentaires, telles que "-S crit-tri"
    #

    variable defaults
    array set defaults {
	base	{url ldap://ldap base o=ulp}
	limite	9999
	cmdldap	{/usr/local/bin/ldapsearch -LLL -H %1$s -b %2$s
			-s sub -z %3$s %6$s %4$s %5$s}
    }

    #
    # Tableau de conversion :
    #   - l'indice dans le tableau correspond au code d�cimal du caract�re
    #   - la case du tableau est la valeur convertie
    # Exemple :
    #   tab(<code correspondant � "�">) => e
    #   tab(<code correspondant � "!">) => <rien>
    #

    variable tableconv
    array set tableconv {
	0	{}	1	{}	2	{}	3	{}
	4	{}	5	{}	6	{}	7	{}
	8	{}	9	{}	10	{}	11	{}
	12	{}	13	{}	14	{}	15	{}

	16	{}	17	{}	18	{}	19	{}
	20	{}	21	{}	22	{}	23	{}
	24	{}	25	{}	26	{}	27	{}	
	28	{}	29	{}	30	{}	31	{}	

	32	{ }	33	{}	34	{}	35	{}	
	36	{}	37	{}	38	{}	39	{}	
	40	{}	41	{}	42	{*}	43	{}	
	44	{}	45	{}	46	{}	47	{}	

	48	{0}	49	{1}	50	{2}	51	{3}	
	52	{4}	53	{5}	54	{6}	55	{7}	
	56	{8}	57	{9}	58	{}	59	{}	
	60	{}	61	{}	62	{}	63	{?}	

	64	{}	65	{a}	66	{b}	67	{c}	
	68	{d}	69	{e}	70	{f}	71	{g}	
	72	{h}	73	{i}	74	{j}	75	{k}	
	76	{l}	77	{m}	78	{n}	79	{o}	

	80	{p}	81	{q}	82	{r}	83	{s}	
	84	{t}	85	{u}	86	{v}	87	{w}	
	88	{x}	89	{y}	90	{z}	91	{}	
	92	{}	93	{}	94	{}	95	{}	

	96	{}	97	{a}	98	{b}	99	{c}	
	100	{d}	101	{e}	102	{f}	103	{g}	
	104	{h}	105	{i}	106	{j}	107	{k}	
	108	{l}	109	{m}	110	{n}	111	{o}	

	112	{p}	113	{q}	114	{r}	115	{s}	
	116	{t}	117	{u}	118	{v}	119	{w}	
	120	{x}	121	{y}	122	{z}	123	{}	
	124	{}	125	{}	126	{}	127	{}	

	128	{}	129	{}	130	{}	131	{}	
	132	{}	133	{}	134	{}	135	{}	
	136	{}	137	{}	138	{}	139	{}	
	140	{}	141	{}	142	{}	143	{}	

	144	{}	145	{}	146	{}	147	{}	
	148	{}	149	{}	150	{}	151	{}	
	152	{}	153	{}	154	{}	155	{}	
	156	{}	157	{}	158	{}	159	{}	

	160	{}	161	{}	162	{}	163	{}	
	164	{}	165	{}	166	{}	167	{}	
	168	{}	169	{}	170	{}	171	{}	
	172	{}	173	{}	174	{}	175	{}	

	176	{}	177	{}	178	{}	179	{}	
	180	{}	181	{}	182	{}	183	{}	
	184	{}	185	{}	186	{}	187	{}	
	188	{}	189	{}	190	{}	191	{}	

	192	{a}	193	{a}	194	{a}	195	{a}	
	196	{a}	197	{a}	198	{a}	199	{c}	
	200	{e}	201	{e}	202	{e}	203	{e}	
	204	{i}	205	{i}	206	{i}	207	{i}	

	208	{d}	209	{n}	210	{o}	211	{o}	
	212	{o}	213	{o}	214	{o}	215	{}	
	216	{o}	217	{u}	218	{u}	219	{u}	
	220	{u}	221	{y}	222	{p}	223	{ss}	

	224	{a}	225	{a}	226	{a}	227	{a}	
	228	{a}	229	{a}	230	{a}	231	{c}	
	232	{e}	233	{e}	234	{e}	235	{e}	
	236	{i}	237	{i}	238	{i}	239	{i}	

	240	{d}	241	{n}	242	{o}	243	{o}	
	244	{o}	245	{o}	246	{o}	247	{}	
	248	{}	249	{u}	250	{u}	251	{u}	
	252	{u}	253	{y}	254	{p}	255	{y}	
    }

    variable tabhtml {
	global {
	    columns {10 90}
	    chars {12 normal}
	    align {left}
	}
	pattern {Normal} {
	    column { }
	    column {
		chars {bold}
	    }
	}
    }
}

##############################################################################
# Acc�s � la base annuaire
##############################################################################

#
# Connexion � la base annuaire
#
# Entr�e :
#   - param�tres :
#	- base (optionnel) : param�tres de la base
# Sortie :
#   - valeur de retour : une cha�ne de connexion
#
# Historique
#   2002/02/11 : pda : cr�ation
#

proc ::annuaire::connect {{base {}}} {
    variable defaults

    if {[string length $base] == 0} then {
	set base $defaults(base)
    }

    return $base
}

#
# D�connexion de la base annuaire
#
# Entr�e :
#   - param�tres :
#	- dbfd : une chaine de connexion
# Sortie : aucune
#
# Historique
#   2002/02/11 : pda : cr�ation
#

proc ::annuaire::disconnect {dbfd} {
    return {}
}

##############################################################################
# Canonisation des noms pour faire des recherches en pr�sence d'accents
##############################################################################

#
# Retrait des majuscules et des accents
#
# Supprime de la cha�ne de recherche tout caract�re non alphanum�rique,
# convertit en minuscules, retire les accents, afin de pouvoir faire
# une recherche de type "demande 'CLAUDE' trouve 'Claud�'".
#
# Entr�e :
#   - param�tres :
#	- chaine : la cha�ne � convertir
# Sortie :
#   - valeur de retour : la cha�ne convertie
#
# Historique
#   1999/01/14 : pda    : conception
#

proc ::annuaire::canoniser {chaine} {
    variable tableconv

    set l [string length $chaine]
    set resultat ""
    for {set i 0} {$i < $l} {incr i} {
	set c [string index $chaine $i]
	scan $c %c d
	append resultat $tableconv($d)
    }
    return $resultat
}


##############################################################################
# Proc�dures pour faciliter l'acc�s aux informations LDAP
##############################################################################

#
# Traite une cha�ne "clef: valeur" de LDAP, �ventuellement avec des
# arguments en base64
#
# Entr�e :
#   - param�tres :
#	- chaine : de la forme "clef: val" ou "clef:: val"
#	- ftab : tableau pass� par variable
# Sortie :
#   - valeur de retour : aucune
#   - param�tre ftab : rempli en ajoutant l'�l�ment val � la liste tab(clef)
#
# Historique
#   2002/02/11 : pda : cr�ation
#

proc ::annuaire::traiter-chaine {chaine ftab} {
    upvar $ftab tab

    if {[regexp {^([^:]*)::[ \t]*(.*)} $chaine bidon clef val]} then {
	set val [::base64::decode $val]
	set clef [string tolower $clef]
	lappend tab($clef) [encoding convertfrom utf-8 $val]
    } elseif {[regexp {^([^:]*):[ \t]*(.*)} $chaine bidon clef val]} then {
	set clef [string tolower $clef]
	lappend tab($clef) $val
    } else {
	# rien
    }
    return
}

#
# Lit un fichier LDIF
#
# Entr�e :
#   - param�tres :
#	- fd : descripteur du fichier utilis�
# Sortie :
#   - valeur de retour : une liste de listes, chacune au format "array get"
#
# Historique
#   2002/02/11 : pda : cr�ation
#

proc ::annuaire::lire-ldif {fd} {
    set resultat {}
    set prec ""
    while {[gets $fd ligne] > -1} {
	if {[string equal $ligne ""]} then {

	    #
	    # Ligne vide : s�parateur d'entr�e, ou d�but de r�sultats
	    # On sort quelque chose seulement s'il y avait une ligne pr�c�dente
	    #
	    if {! [string equal $prec ""]} then {
		::annuaire::traiter-chaine $prec tab
		lappend resultat [array get tab]
		catch {unset tab}
	    }
	    set prec ""

	} elseif {[regexp {^[ \t]} $ligne]} then {

	    #
	    # Ligne de continuation
	    # On accumule dans la ligne pr�c�dente
	    #
	    set ligne [string trim $ligne]
	    append prec $ligne

	} else {

	    #
	    # Ligne "normale" (clef: val)
	    # On sort la pr�c�dente ligne si besoin est
	    #
	    if {! [string equal $prec ""]} then {
		::annuaire::traiter-chaine $prec tab
	    }
	    set prec $ligne

	}
    }

    #
    # On est arriv� au bout.
    # Ne pas oublier la derni�re entr�e.
    #
    if {! [string equal $prec ""]} then {
	::annuaire::traiter-chaine $prec tab
	lappend resultat [array get tab]
    }
    return $resultat
}

#
# Recherche LDAP
#
# Entr�e :
#   - param�tres :
#	- dbfd : identificateur de la base annuaire
#	- limite : nb maximum d'entr�es retourn�es
#	- flitre : filtre de recherche LDAP
#	- attributs : attributs recherch�s
#	- tri (optionnel) : l'attribut pour lequel on fait un tri
# Sortie :
#   - valeur de retour : une liste de listes, chacune au format "array get"
#
# Historique
#   2002/02/11 : pda : cr�ation
#   2002/02/12 : pda : ajout du crit�re de tri
#

proc ::annuaire::ldapsearch {dbfd limite filtre attributs {tri pas-de-tri}} {
    variable defaults

    array set ldappar $dbfd

    if {[string equal $tri "pas-de-tri"]} then {
	set t ""
    } else {
	if {[string equal $tri ""]} then {
	    set t "-S "
	} else {
	    set t "-S $tri"
	}
    }

    set cmd [format $defaults(cmdldap) \
			$ldappar(url) $ldappar(base) $limite \
			$filtre $attributs \
			$t \
		    ]

    set fd [open "|$cmd" r]
    set found [::annuaire::lire-ldif $fd]
    catch {close $fd}

    return $found
}

##############################################################################
# Interface de recherche
##############################################################################

#
# Recherche d'un individu par nom
#
# Entr�e :
#  - param�tres :
#	- dbfd : chaine de connexion
#	- name : nom de l'individu
#	- limite (optionnel) : limite du nb de lignes (si 0 pas de limite)
# Sortie :
#  - valeur de retour : liste de la forme
#	{{num_individu num_service} nom pr�nom {liste des libell�s du service}
#		batiment etage bureau tel fax titre email web}
#
# Historique
#   2002/02/11 : pda : cr�ation
#

proc ::annuaire::chercher-par-nom {dbfd name {limite 0}} {
    variable defaults

    if {$limite <= 0} then { set limite $defaults(limite) }

    set found {}
    set name [::annuaire::canoniser $name]

    #
    # Modification du masque de recherche  pour que le grep
    # accepte les caract�res de substitution
    #         . devient null
    #         ^ devient null
    #         $ devient null
    #         ; devient null
    #         * devient .*
    #         ? devient .
    #         tout caract�re en dehors de l'alphabet devient .
    #

    regsub -all {[\.\^\$\;]} $name "" sname
    regsub -all {\?} $sname {.} sname
    regsub -all { } $sname {.} sname
    regsub -all {\*} $sname {.*} sname

    #
    # Recherche dans la base
    #

    set found [::annuaire::ldapsearch $dbfd $limite "(sn=$sname)" "*"]

    #
    # Mise en forme du r�sultat
    #

    set resultat {}
    foreach p $found {
	array set tab $p

	#
	# La liste a constituer doit avoir le format suivant
	#		{{num_individu num_service titre}
	#			nom pr�nom {liste des libell�s du service}
	#			batiment etage bureau tel fax titre email web}
	#
	# Essayer de faire au mieux compte-tenu des attributs
	# LDAP retourn�s
	#

	set r {}
	lappend r [list $tab(dn) {}]

	foreach attrdesc {
				{sn				single}
				{givenname			single}
				{ou				multiple}
				{RIEN				multiple}
				{RIEN				multiple}
				{{postaladdress postalcode l}	single}
				{telephonenumber		single}
				{facsimileTelephonenumber	single}
				{RIEN				multiple}
				{mail				single}
				{labeleduri			single}
			    } {
	    set attr [lindex $attrdesc 0]
	    set type [lindex $attrdesc 1]
	    set val ""
	    foreach a $attr {
		if {[info exists tab($a)]} then {
		    if {[string equal $type "single"]} then {
			set t [lindex $tab($a) 0]
		    } else {
			set t $tab($a)
		    }
		} else {
		    set t ""
		}
		if {[string equal $val ""]} then {
		    append val $t
		} else {
		    append val " $t"
		}
	    }
	    lappend r $val
	}

	catch {unset tab}

	lappend resultat $r
    }
    return $resultat
}

##############################################################################
# Pr�sentation d'une entr�e de l'annuaire en HTML
##############################################################################

#
# Met en forme (en HTML, zoli et tout) le r�sultat trouv�.
#
# Entr�e :
#   - param�tres :
#	- entree : liste telle que fournie par chercher-par-nom
# Sortie :
#   - valeur de retour : cha�ne HTML, pr�te � �tre imprim�e
#
# Historique
#   1998/../.. : droopy : conception
#   1999/03/26 : pda    : documentation
#   1999/03/26 : pda    : simplification et renvoi dans une cha�ne
#   1999/07/13 : cty    : adaptation pour base postgress
#   1999/08/23 : cty    : adaptation pour nouvelle proc�dure rechercher
#   2000/07/24 : pda    : mise en package
#   2002/07/29 : pda    : utilisation d'un tableau plut�t qu'un <PRE>...</PRE>
#

proc ::annuaire::format-html {entree} {
    variable tabhtml

    set donnees {}
    foreach x {
		{Nom		1	all}
		{Pr�nom		2	all}
		{T�l�phone	7	all}
		{Service	3	first}
		{Fonction	9	all}
		{B�timent	4	all}
		{�tage		5	all}
		{Bureau		6	all}
		{Fax		8	all}
		{Email		10	all}
		{Web		11	all}
	    } {
	set val [lindex $entree [lindex $x 1]]
	if {[string equal [lindex $x 2] "first"]} then {
	    set val [lindex $val 0]
	}
	lappend donnees [list Normal [lindex $x 0] $val]
    }

    return [::arrgen::output "html" $tabhtml $donnees]
} 
