; X-Assembler

	IDEAL
	P386
	MODEL	TINY
	CODESEG

compak	=	1b00h

l_icl	=	1024
l_org	=	4096
l_lab	=	48000

STRUC	com
c_code	db	?
c_name	db	?,?,?
c_vec	dw	?
	ENDS

STRUC	icl
prev	dw	?
handle	dw	?
line	dd	?
flags	db	?
m_eofl	=	1
nam	db	?
	ENDS

STRUC	lab
l_val	dw	?
flags	db	?
b_sign	=	7
m_sign	=	80h
m_lnus	=	40h
m_ukp1	=	20h
len	db	?
nam	db	?
	ENDS

STRUC	movt
m_code	db	?
m_vec	dw	?
	ENDS

;[flags]
m_pass	=	1
m_skip	=	4
m_norg	=	8
m_rorg	=	10h
m_rqff	=	20h
b_hdr	=	6
m_hdr	=	40h

;[swits]
m_swc	=	1
m_swi	=	2
m_swl	=	4
m_swo	=	8
m_sws	=	10h
m_swt	=	20h

;[flist]
m_lstc	=	1
m_lsti	=	2
m_lstl	=	4
m_lsto	=	8
m_lsts	=	m_lsto+m_lstl+m_lsti

nhand	=	-1	;null handle
eol	equ	13,10
eot	equ	13,10,'$'

MACRO	lda	_rg	;shorter than 'mov (e)ax, _rg'
_rge	SUBSTR	<_rg>, 1, 1
IFIDNI	_rge, <e>
	xchg	eax, _rg
ELSE
	xchg	ax, _rg
ENDIF
	ENDM

MACRO	sta	_rg	;shorter than 'mov _rg, (e)ax'
_rge	SUBSTR	<_rg>, 1, 1
IFIDNI	_rge, <e>
	xchg	_rg, eax
ELSE
	xchg	_rg, ax
ENDIF
	ENDM

MACRO	dos	_func
	IFNB	<_func>
	IF	_func and 0ff00h
	mov	ax, _func
	ELSE
	mov	ah, _func
	ENDIF
	ENDIF
	int	21h
	ENDM

MACRO	file	_func, _errtx
	IFNB	<_errtx>
	mov	[errmsg], offset _errtx
	ENDIF
	IF	_func and 0ff00h
	mov	ax, _func
	ELSE
	mov	ah, _func
	ENDIF
	call	xdisk
	ENDM

MACRO	print	_text
	IFNB	<_text>
	mov	dx, offset _text
	ENDIF
	dos	9
	ENDM

MACRO	error	_err
	push	offset _err
	jmp	errln
	ENDM

MACRO	jpass1	_dest
	test	[flags], m_pass
	jz	_dest
	ENDM

MACRO	jpass2	_dest
	test	[flags], m_pass
	jnz	_dest
	ENDM

MACRO	jquote	_dest
	cmp	bp, offset var
	jne	_dest
	ENDM

MACRO	jnquote	_dest
	cmp	bp, offset var
	je	_dest
	ENDM

MACRO	cmd	_oper
_tp	SUBSTR	<_oper>, 4, 2
_tp	CATSTR	<0>, &_tp, <h>
	db	_tp
	IRP	_ct,<3,2,1>
_tp	SUBSTR	<_oper>, _ct, 1
%	db	'&_tp'
	ENDM
_tp	SUBSTR	<_oper>, 6
	dw	_tp
	ENDM

MACRO	opr	_oper
_tp	SUBSTR	<_oper>, 1, 1
	db	_tp
_tp	SUBSTR	<_oper>, 2
_tp	CATSTR	<v_>, _tp
	dw	_tp
	ENDM

MACRO	undata
	db	6 dup(?)
lstnum	db	5 dup(?)
lstspa	db	?
lstorg	db	26 dup(?)
line	db	258 dup(?)
tlabel	db	256 dup(?)
objnam	db	128 dup(?)
lstnam	db	128 dup(?)
tabnam	db	128 dup(?)
t_icl	db	l_icl dup(?)
t_org	db	l_org dup(?)
	ENDM

;*****************************

zero	db	100h dup(?)
start:
IFDEF	compak
	undata
	db	compak+start-$ dup(?)
ENDIF

	print	hello
	mov	di, 81h
	movzx	cx, [di-1]
	jcxz	usg		; brak parametrow - usage
	mov	al, ' '
	repe	scasb
	je	usg		; same spacje - usage
	dec	di
	inc	cx
	mov	si, di
	mov	al, '?'
	repne	scasb
	jne	begin		; '?' - usage

usg:	print	usgtxt		; usage - instrukcja
	dos	4c03h

begin:	lodsb			; pobierz nazwe
	cmp	al, '/'
	je	usg		; najpierw musi byc nazwa
	mov	di, offset (icl t_icl).nam+1
	lea	dx, [di-1]
	xor	ah, ah
	mov	[tabnam], ah	; nie ma nazwy tabeli symboli
dinam	equ	di-t_icl-offset (icl).nam
mnam1:	dec	di		; zapisz do t_icl.nam, ...
	mov	[objnam+dinam], ax	; ... objnam, ...
	mov	[lstnam+dinam], ax	; ... lstnam
	stosw
	lodsb
	cmp	al, ' '
	je	mnam2
	cmp	al, '/'
	je	mnam2
	cmp	al, 0dh
	jne	mnam1
mnam2:	call	adasx		; doczep .ASX
	mov	[fslen], di
chex1:	dec	di
	cmp	[byte di], '.'
	jne	chex1
	mov	[byte objnam+dinam], '.'	; doczep .OBX
	mov	[dword objnam+dinam+1], 'XBO'
	mov	[byte lstnam+dinam], '.'	; doczep .LST
	mov	[dword lstnam+dinam+1], 'TSL'

gsw0:	dec	si
gsw1:	lodsb			; pobierz switche
	cmp	al, ' '
	je	gsw1		; pomin spacje
	cmp	al, 0dh
	je	gswx
	cmp	al, '/'
	jne	usg		; musi byc '/'
	lodsb
	and	al,0dfh		; mala litera -> duza
	mov	di, offset swilet
	mov	cx, 6
	repne	scasb
	jne	usg		; nie ma takiego switcha
	bts	[word swits], cx	; sprawdz bit i ustaw
	jc	usg		; juz byl taki
	mov	di, offset lstnam
	mov	ecx, 'TSL'
	cmp	al, 'L'
	je	gsw2		; /L
	mov	di, offset tabnam
	mov	ecx, 'BAL'
	cmp	al, 'T'
	je	gsw2		; /T
	cmp	al, 'O'
	jne	gsw1		; switch bez parametru
	cmp	[byte si], ':'
	jne	usg		; /O wymaga ':'
	mov	di, offset objnam
	mov	ecx, 'XBO'

gsw2:	lodsb
	cmp	al, ':'
	jne	gsw0
	mov	dx, di		; jesli ':', to ...
gsw3:	lodsb			; ... pobierz nazwe
	stosb
	cmp	al, ' '
	je	gsw4
	cmp	al, '/'
	je	gsw4
	cmp	al, 0dh
	jne	gsw3
gsw4:	mov	[byte di-1], 0
	lda	ecx		; doczep ecx
	call	adext
	jmp	gsw0
gswx:	mov	al, [swits]
	not	al
	and	al, m_lstl+m_lstc
	or	al, m_lsto
	mov	[flist], al
	mov	bp, offset var

npass:	mov	[orgvec], offset t_org-2
	mov	di, [fslen]

opfile:	call	fopen

main:	mov	bx, [iclen]
	mov	bx, [(icl bx).prev]
	test	[(icl bx).flags], m_eofl
	jnz	filend		; czy byl juz koniec pliku ?

	mov	di, offset line	; ... nie - omin ewentualny LF
	call	fread1
	jz	filend
	cmp	[line], 0ah
	je	skiplf
	inc	di
skiplf:
	mov	bx, [iclen]
	mov	bx, [(icl bx).prev]
	inc	[(icl bx).line]	; zwieksz nr linii w pliku
	inc	[lines]		; ilosc wszystkich linii
	test	[swits], m_swi
	jz	gline1		; czy /I
	and	[flist], not m_lsti	; ... tak
	cmp	bx, offset t_icl
	jbe	gline1		; czy includowany plik ?
	or	[flist], m_lsti	; ... tak, nie listuj

gline1:	cmp	di, offset line+256
	jnb	linlon
	call	fread1
	jz	eof
	mov	al, 0dh
	scasb
	jne	gline1		; czytaj do CR
	dec	di
	jmp	syntax

eof:	mov	bx, [iclen]	; koniec pliku
	or	[(icl bx).flags], m_eofl

syntax:	call	lspeol		; zapisz CR/LF i zapamietaj dlugosc linii
	mov	si, offset line
	mov	al, [si]
	cmp	al, 0dh
	je	lsteol
	cmp	al, '*'
	je	lstrem
	cmp	al, ';'
	je	lstrem
	cmp	al, '|'
	je	lstrem
	test	[flags], m_skip
	jz	nskip		; czy byl falszywy warunek ?
skip1:	call	get		; ... tak - omin etykiete ...
	cmp	al, ' '
	je	skip2
	cmp	al, 9
	jne	skip1
skip2:	call	space1		; omin spacje
	lodsd			; sprawdz komende
	and	eax, 0dfdfdfh
	cmp	eax, 'DNE'
	je	filend
	push	offset lstrem
	cmp	eax, 'TFI'	; IFT
	je	skift
	cmp	eax, 'SLE'	; ELS
	je	skels
	cmp	eax, 'FIE'	; EIF
	jne	skret
	call	p_eif
	dec	[sift]
	jns	skret
	and	[flags], not m_skip
	inc	[sift]	;0
skret:	ret
skift:	call	shlelf
	inc	[sift]
	ret
skels:	call	btself
	cmp	[sift], 0
	jnz	skret
	jmp	fliski

lsteol:	call	chklst
	jnz	main
	mov	di, offset lstspa
	call	lspeol
	call	putlnm
	jmp	main
lstrem:	call	chklst
	jnz	main
	mov	di, offset lstspa+1
	call	putlsp
	jmp	main

nskip:	mov	[labvec], 0
	cmp	al, ' '
	je	s_one
	cmp	al, 9
	je	s_one
	cmp	al, ':'		; linia powtarzana
	jne	labdef
	inc	si
	call	getuns
	jc	unknow
	test	ax, ax
	jz	lstrem
	jmp	s_cmd

labdef:	jpass2	deflp2		; jest etykieta
	call	flabel		; definicja etykiety w pass 1
	jnc	ltwice
	mov	di, [laben]
	mov	[labvec], di
	mov	ax, [origin]
	stosw			; domyslnie equ *
	mov	al, m_lnus
	mov	ah, dl
	stosw
	mov	cx, dx
	sub	cl, 4
	lda	si
	mov	si, offset tlabel
	rep	movsb		; przepisz nazwe
	sta	si
	mov	[laben], di
	cmp	di, offset t_lab+l_lab-4
	jb	s_one
	error	e_tlab

ltwice:	error	e_twice

deflp2:	call	rlabel		; definicja etykiety w pass 2
	mov	ax, [pslab]
	mov	[labvec], ax
	add	[pslab], dx	; oznacz jako minieta

s_one:	mov	ax, 1
s_cmd:	mov	[times], ax
s_cmd0:	lodsb
	cmp	al, ' '
	je	s_cmd0
	cmp	al, 9
	je	s_cmd0
	cmp	al, 0dh
	jne	s_cmd1
	cmp	[byte high labvec], 0
	jne	uneol		; niedozwolona linia z sama etykieta
	cmp	[times], 1
	jne	uneol		; niedozwolona linia z samym licznikiem
	jmp	lsteol
s_cmd1:	dec	si
	mov	di, offset lstorg
	test	[flags], m_norg
	jnz	nlorg
	mov	ax, [origin]
	call	phword		; listuj * hex
	mov	al, ' '
	stosb
nlorg:	mov	[lstidx], di
	mov	[cmdvec], si

rdcmd:	lodsw			; wez trzy litery
 	and	ax, 0dfdfh
	xchg	al, ah
	shl	eax, 16
	mov	ah, 0dfh
	and	ah, [si]
	jquote	lbnox		; jezeli nie cytujemy ...
	test	[flags], m_norg
	jz	lbnox		; ... i nie bylo ORG ...
	cmp	[byte high labvec], 0
	je	lbnox		; ... a jest etykieta ...
	cmp	eax, 'EQU' shl 8
	jne	noorg		; ... to dozwolony jest tylko EQU
lbnox:	inc	si		; przeszukiwanie polowkowe
	mov	di, offset comtab
	mov	bx, 64*size com
sfcmd1:	mov	al, [(com di+bx).c_code]
	cmp	eax, [dword (com di+bx).c_code]
	jb	sfcmd3
	jne	sfcmd2

	cmp	al, 0ffh	; czy dyrektywa, ktorej nie wolno powtarzac ?
	jne	rncmd1
	cmp	[times], 1	; a powtarzamy ?
	jne	ntrep
rncmd1:	btr	ax, 0		; czy dyrektywa, ktorej nie wolno cytowac ?
	jnc	rncmd2
	jquote	ntquot		; a cytujemy ?
rncmd2:	mov	[cod], al
	call	[(com di+bx).c_vec]	; wywolaj procedure
	call	linend
	dec	[times]
	jz	main
	mov	si, [cmdvec]
	jmp	rdcmd
sfcmd2:	add	di, bx
	cmp	di, offset comend
	jb	sfcmd3
	sub	di, bx
sfcmd3:	shr	bx, 1
	cmp	bl, 3
	ja	sfcmd1
	mov	bl, 0
	je	sfcmd1
	error	e_inst

ntrep:	error	e_crep

ntquot:	error	e_quote

skend:	call	chklst
	jnz	filend
	mov	di, offset lstspa+1
	call	putlsp

filend:	call	fclose
	cmp	bx, offset t_icl
	ja	main
	jpass2	fin

	cmp	[elflag], 1
	jne	miseif
	or	[flags], m_pass+m_norg+m_rorg+m_rqff+m_hdr
	and	[flist], not m_lsto
	jmp	npass

fin:	mov	bx, [ohand]
	mov	[errmsg], offset e_wrobj
	call	hclose
	test	[swits], m_swt
	jz	nlata			; czy /T ?
	cmp	[laben], offset t_lab	; ... tak
	jbe	nlata			; czy tablica pusta ?
	cmp	[byte tabnam], 0	; ... nie
	jnz	oplata		; czy dana nazwa ?
	cmp	[lhand], nhand	; ... nie
	jne	latt1		; czy otwarty listing ?
	call	opnlst		; ... nie - otworz
	jmp	latt2
latt1:	call	plseol
	jmp	latt2
oplata:	call	lclose		; zamknij listing
	mov	dx, offset tabnam
	call	opntab		; otworz tablica
latt2:	mov	dx, offset tabtxt
	mov	cx, tabtxl
	call	putlad
	mov	si, offset t_lab
lata1:	mov	di, offset lstnum
	mov	eax, '    '
	test	[(lab si).flags], m_lnus
	jz	lata2
	mov	al, 'n'
lata2:	test	[(lab si).flags], m_ukp1
	jz	lata3
	mov	ah, '2'
lata3:	stosd
	mov	ax, [(lab si).l_val]
	test	[(lab si).flags], m_sign
	jz	lata4
	mov	[byte di-1], '-'
	neg	ax
lata4:	call	phword
	mov	al, ' '
	stosb
	mov	cx, (offset (lab)-offset (lab).nam) and 0ffh
	add	cl, [(lab si).len]
	add	si, offset (lab).nam
	rep	movsb
	call	lspeol
	call	putlst
	cmp	si, [laben]
	jb	lata1

nlata:	call	lclose
	mov	eax, [lines]
	shr	eax, 1
	call	pridec
	print	lintxt
	mov	eax, [bytes]
	test	eax, eax
	jz	zrbyt
	call	pridec
	print	byttxt
zrbyt:	mov	ax, [exitcod]
	dos

linlon:	push	offset e_long
	jmp	erron

miseif:	push	offset e_meif
	jmp	erron

; ERROR
errln:	call	ppline
erron:	call	prname
	print	errtxt
	pop	si
	call	prline
	dos	4c02h

; WARNING
warln:	call	ppline
waron:	call	prname
	print	wartxt
	pop	ax
	pop	si
	push	ax
	mov	[byte exitcod], 1
	jmp	prline

prname:	mov	bx, [iclen]
	cmp	bx, offset t_icl
	jna	prnamx
	mov	di, [(icl bx).prev]
	push	di
	lea	dx, [(icl di).nam]
	mov	[byte bx-1], '$'
	print
	mov	dl, ' '
	dos	2
	mov	dl, '('
	dos	2
	pop	bx
	mov	eax, [(icl bx).line]
	call	pridec
	mov	dl, ')'
	dos	2
	mov	dl, ' '
	dos	2
prnamx:	ret

ppline:	mov	si, offset line
prline:	mov	dl, [si]
	dos	2
	inc	si
	cmp	[byte si-1], 0ah
	jne	prline
	ret

; I/O
xdisk:	dos
	jnc	cloret
	push	[errmsg]
	jmp	erron

icler:	push	offset e_icl
	jmp	erron

lclose:	mov	bx, nhand	; mov	bx, [lhand]
	xchg	bx, [lhand]	; mov	[lhand], nhand
	mov	[errmsg], offset e_wrlst
hclose:	cmp	bx, nhand
	je	cloret
	file	3eh
cloret:	ret

fopen:	cmp	di, offset t_icl+l_icl-2
	jnb	icler
	mov	bx, [iclen]
	mov	[(icl bx).line], 0
	mov	[(icl bx).flags], 0
	lea	dx, [(icl bx).nam]
	mov	[(icl di).prev], bx
	mov	[iclen], di
	file	3d00h, e_open
	mov	bx, [iclen]
	mov	bx, [(icl bx).prev]
	mov	[(icl bx).handle], ax
	ret

fread1:	mov	dx, di
	mov	cx, 1
fread:	mov	ah, 3fh
fsrce:	mov	bx, [iclen]
	mov	bx, [(icl bx).prev]
	mov	bx, [(icl bx).handle]
	mov	[errmsg], offset e_read
	call	xdisk
	test	ax, ax
	ret

fclose:	mov	ah, 3eh
	call	fsrce
	mov	bx, [iclen]
	cmp	bx, [srcen]
	jne	fclos1
	mov	[srcen], 0
fclos1:	mov	bx, [(icl bx).prev]
	mov	[iclen], bx
	ret

putwor:	push	ax		; zapisz slowo do pliku
	call	putbyt
	pop	ax
	mov	al, ah
putbyt:	jpass1	putx		; zapisz bajt
	mov	[obyte], al
	cmp	[ohand], nhand
	jne	putb1		; otwarty object ?
	mov	dx, offset objnam	; ... nie - otworz
	xor	cx, cx
	file	3ch, e_crobj
	mov	[ohand], ax
	print	objtxt
putb1:	mov	bx, [ohand]
	mov	dx, offset obyte
	mov	cx, 1
	file	40h, e_wrobj
	inc	[bytes]
putx:	ret

orgwor:	push	ax
	call	phword
	pop	ax
	jmp	putwor

chorg:	test	[flags], m_norg
	jz	putx
noorg:	error	e_norg

tmorgs:	error	e_orgs

savwor:	push	ax
	call	savbyt
	pop	ax
	mov	al, ah

savbyt:	jquote	xquot
	mov	[sbyte], al
	call	chorg
	test	[flags], m_hdr
	jz	savb1
	mov	ax, [origin]
	test	[flags], m_rorg
	jnz	borg1
	cmp	ax, [curorg]
	je	borg3
borg1:	add	[orgvec], 2
	jpass1	borg2
	mov	di, offset lstorg
	test	[flags], m_rqff
	jz	noff
	mov	ax, 0ffffh
	call	orgwor
	mov	ax, ' >'
	stosw
	mov	ax, [origin]
noff:	call	orgwor
	mov	al, '-'
	stosb
	mov	bx, [orgvec]
	mov	ax, [bx]
	call	orgwor
	mov	ax, ' >'
	stosw
	mov	[lstidx], di
	mov	ax, [origin]
borg2:	and	[flags], not (m_rorg+m_rqff)
borg3:	jpass2	borg4
	mov	di, [orgvec]
	stosw
borg4:	inc	ax
	mov	[curorg], ax

savb1:	inc	[origin]
	test	[flist], m_lsts
	jnz	lsbpop
	mov	di, [lstidx]
	cmp	di, offset line-3
	jae	lstxtr
	mov	al, [sbyte]
	call	phbyte
	mov	al, ' '
lstpls:	stosb
	mov	[lstidx], di
lsbpop:	mov	al, [sbyte]
	jmp	putbyt
lstxtr:	ja	lsbpop
	mov	al, '+'
	jmp	lstpls

chklst:	mov	al, m_lsts
	test	[flags], m_skip
	jz	chkls1
	mov	al, m_lsts+m_lstc
chkls1:	test	al, [flist]
	ret

; Stwierdza blad, jesli nie spacja, tab lub eol
linend:	lodsb
	cmp	al, 0dh
	je	linen1
	cmp	al, ' '
	je	linen1
	cmp	al, 9
	je	linen1
	error	e_xtra
linen1:	test	[flist], m_lsts
	jnz	linret
	cmp	[times], 1
	jne	linret
	mov	di, [lstidx]
putlsp:	call	putspa
; Listuje linie z numerem
putlnm:	mov	di, offset lstspa
	mov	bx, [iclen]
	mov	bx, [(icl bx).prev]
	mov	eax, [(icl bx).line]
	call	numdec
lstlsp:	dec	di
	mov	[byte di], ' '
	cmp	di, offset lstnum
	ja	lstlsp

	mov	bx, [iclen]
	cmp	bx, [srcen]
	je	nlsrc		; czy zmienil sie asemblowany plik ?
	mov	[srcen], bx	; ... tak
	cmp	[lhand], nhand
	jne	lsrc1		; otwarty listing ?
	call	opnlst		; ... nie - otworz
lsrc1:	mov	dx, offset srctxt
	mov	cx, offset srctxl
	call	putlad		; komunikat o nowym source'u
	mov	bx, [iclen]
	mov	cx, bx
	mov	bx, [(icl bx).prev]
	lea	dx, [(icl bx).nam]
	stc
	sbb	cx, dx
	call	putlad		; nazwa
	call	plseol
nlsrc:
	test	[swits], m_sws
	jnz	putlst		; jezeli nie ma /S ...
	mov	si, offset lstnum
	mov	di, si		; ... zamien spacje na taby
spata1:	xor	dl, dl
spata2:	lodsb
	stosb
	cmp	al, 0ah
	je	spatax
	cmp	al, 9
	je	spata1
	dec	dx
	cmp	al, ' '
	jne	spata2
	and	dx, 7
	jz	spata2
	mov	cx, dx
	mov	bx, si
spata3:	cmp	al, [bx]
	jne	spata2
	inc	bx
	loop	spata3
	mov	[byte di-1], 9
	mov	si, bx
	jmp	spata1
spatax:	call	lsplen

; Zapis linii lstnum o dlug. linlen
putlst:	mov	dx, offset lstnum
	mov	cx, [linlen]
putlad:	mov	bx, [lhand]
	file	40h, e_wrlst
linret:	ret

opnlst:	mov	dx, offset lstnam
opntab:	xor	cx, cx
	file	3ch, e_crlst
	mov	[lhand], ax
	print	lsttxt
	mov	dx, offset hello
	mov	cx, hellen
	jmp	putlad

plseol:	mov	dx, offset eoltxt
	mov	cx, 2
	jmp	putlad

lspeol:	mov	ax, 0a0dh
	stosw
lsplen:	lea	ax, [di+zero-lstnum]
	mov	[linlen], ax
	ret

adasx:	mov	eax, 'XSA'
; Dodaj rozszerzenie nazwy, gdy go nie ma
; we: dx,di-poczatek,koniec nazwy; eax-rozszerzenie
adext:	mov	bx, di
adex1:	dec	bx
	cmp	[byte bx], '\'
	je	adex2
	cmp	[byte bx], '.'
	je	adexr
	cmp	bx, dx
	ja	adex1
adex2:	mov	[byte di-1], '.'
	stosd
adexr:	ret

; Zapisz dziesietnie eax; di-koniec liczby
numdec:	mov	ebx, 10
numde1:	cdq
	div	ebx
	add	dl, '0'
	dec	di
	mov	[di], dl
	test	eax, eax
	jnz	numde1
	ret

; Wyswietl dziesietnie eax
pridec:	mov	di, offset dectxt+10
	call	numdec
	mov	dx, di
	print
	ret

; Zapisz hex ax od [di]
phword:	push	ax
	mov	al, ah
	call	phbyte
	pop	ax
phbyte:	push	ax
	shr	al, 4
	call	phdig
	pop	ax
	and	al, 0fh
phdig:	cmp	al, 10
	sbb	al, 69h
	das
	stosb
	ret

; Pobierz znak (eol=error)
get:	lodsb
	cmp	al, 0dh
	je	uneol
	ret
uneol:	error	e_uneol

ilchar:	error	e_char

; Omin spacje i tabulatory
spaces:	call	get
	cmp	al, ' '
	je	space1
	cmp	al, 9
	je	space1
	error	e_spac
space1:	call	get
	cmp	al, ' '
	je	space1
	cmp	al, 9
	je	space1
	dec	si
rstret:	ret

; Zapisz spacje od di do line
putspa:	mov	cx, offset line
	sub	cx, di
	mov	al, ' '
	rep	stosb
	mov	[lstspa], al
	ret

; Pobierz nazwe pliku
rfname:	call	spaces
	mov	di, offset (icl).nam
	add	di, [iclen]
; Pobierz lancuch do [di]
rstr:	call	get
	cmp	al, "'"
	je	rstr0
	cmp	al, '"'
	jne	strer
rstr0:	mov	dx, di
	mov	ah, al
rstr1:	call	get
	stosb
	cmp	al, ah
	jne	rstr1
	lodsb
	cmp	al, ah
	je	rstr1
	dec	si
	mov	[byte di-1], 0
	lea	cx, [di-1]
	sub	cx, dx
	jnz	rstret

strer:	error	e_str

; Przepisz etykiete do tlabel (wyj: dx-dl.etykiety+4)
rlabel:	mov	di, offset tlabel
	mov	[byte di], 0
rlab1:	lodsb
	cmp	al, '0'
	jb	rlabx
	cmp	al, '9'
	jbe	rlab2
	cmp	al, 'A'
	jb	rlabx
	cmp	al, 'Z'
	jbe	rlab2
	cmp	al, '_'
	je	rlab2
	cmp	al, 'a'
	jb	rlabx
	cmp	al, 'z'
	ja	rlabx
	add	al, 'A'-'a'
rlab2:	stosb
	cmp	di, offset tlabel+252
	jb	rlab1
	jmp	linlon
rlabx:	cmp	[byte tlabel], 'A'
	jb	ilchar
	lea	dx, [di+zero-tlabel+lab.nam]
	dec	si
	ret

; Czytaj etykiete i szukaj w t_lab
; wyj: dx-dlugosc etykiety+4
; C=0: znaleziona, bx=adres wpisu
; C=1: nie ma jej
flabel:	call	rlabel
	push	si
	xor	cx, cx
	mov	si, offset t_lab
	mov	ax, [laben]
	dec	ax
flab1:	add	si, cx
	cmp	ax, si
	jb	flabx
	mov	cl, [(lab si).len]
	cmp	cl, dl
	jne	flab1
	add	si, offset (lab).nam
	sub	cl, offset (lab).nam
	mov	di, offset tlabel
	repe	cmpsb
	jne	flab1
	lea	bx, [si+tlabel-offset (lab).nam]
	sub	bx, di	; c=0
flabx:	pop	si
	ret

wropar:	error	e_wpar

spaval:	call	spaces
; Czytaj wyrazenie i zwroc jego wartosc w [val]
; (C=1 wartosc nieokreslona w pass 1)
getval:	xor	bx, bx
	mov	[ukp1], bh
	push	bx

v_lop:
v_par1:	inc	bh
	call	get
	cmp	al, '['
	je	v_par1
	cmp	al, '('
	je	wropar
	cmp	al, '-'
	je	valuem
	dec	si
	mov	al, '+'
valuem:	mov	bl, al
	xor	eax, eax
	call	get
	cmp	al, '*'
	je	valorg
	cmp	al, "'"
	je	valchr
	cmp	al, '"'
	je	valchr
	cmp	al, '^'
	je	valreg
	cmp	al, '{'
	je	valquo
	mov	di, -1
	xor	edx, edx
	mov	ecx, 16
	cmp	al, '$'
	je	rdnum3
	mov	cl, 2
	cmp	al, '%'
	je	rdnum3
	mov	cl, 10
	cmp	al, '0'
	jb	ilchar
	cmp	al, '9'
	ja	vlabel

rdnum1:	cmp	al, '9'
	jbe	rdnum2
	and	al, 0dfh
	cmp	al, 'A'
	jb	value0
	add	al, '0'+10-'A'
rdnum2:	sub	al, '0'
	cmp	al, cl
	jnb	value0
	movzx	edi, al
	lda	edx
	mul	ecx
	add	eax, edi
	js	toobig
	adc	edx, edx
	jnz	toobig
	sta	edx
rdnum3:	lodsb
	jmp	rdnum1

vlabel:	push	bx
	dec	si
	call	flabel
	jnc	vlabfn
	jpass1	vlukp1
	error	e_undec
vlabfn:	jpass1	vlchuk
	and	[(lab bx).flags], not m_lnus
	cmp	bx, [pslab]
	jb	vlchuk
	test	[(lab bx).flags], m_ukp1
	jz	vlukp1
	error	e_fref
vlchuk:	test	[(lab bx).flags], m_ukp1
	jz	vlabkn
vlukp1:	mov	[ukp1], 0ffh
vlabkn:	bt	[word (lab bx).flags], b_sign
	sbb	eax, eax
	mov	ax, [(lab bx).l_val]
	pop	bx
	jmp	value1

valorg:	call	chorg
	mov	ax, [origin]
	jmp	value1

valchr:	mov	dl, al
	call	get
	cmp	al, dl
	jne	valch1
	lodsb
	cmp	al, dl
	jne	strer
valch1:	cmp	dl, [si]
	jne	strer
	inc	si
	cmp	[byte si], '*'
	jne	value1
	inc	si
	xor	al, 80h
	jmp	value1

valreg:	call	get
	cmp	al, '4'
	ja	ilchar
	sub	al, '0'
	jb	ilchar
	add	al, 0d0h
	mov	ah, al
	call	get
	cmp	al, '9'
	jbe	valre1
	and	al, 0dfh
	cmp	al, 'A'
	jb	ilchar
	add	al, '0'+10-'A'
valre1:	sub	al, '0'
	cmp	al, 0fh
	ja	ilchar	
	cmp	ah, 0d1h
	jne	value1
	sub	ax, 0f0h
	jmp	value1

valquo:	jquote	rcquot
	push	bx
	mov	[quotsp], sp
	mov	bp, offset var2
	jmp	rdcmd
xquot:	mov	bp, offset var
	mov	sp, [quotsp]
	push	ax
	call	get
	cmp	al, '}'
	jne	msquot
	pop	ax
	xor	ah, ah
	cwde
	pop	bx
	jmp	value1

rcquot:	error	e_rquot

msquot:	error	e_mquot

value0:	dec	si
	test	di, di
	js	ilchar
	lda	edx
value1:	cmp	bl, '-'
	jne	value2
	neg	eax
value2:	push	eax
v_par2:	dec	bh
	js	mbrack
	lodsb
	cmp	al, ']'
	je	v_par2

	mov	ah, [si]
	mov	di, offset opert2
	mov	cx, noper2
	repne	scasw
	je	foper2		; operator 2-znakowy
	mov	cx, noper1
	repne	scasb
	je	foper1		; operator 1-znakowy
	test	bh, bh		; koniec wyrazenia
	jnz	mbrack		; musza byc zamkniete nawiasy
	dec	si
	mov	di, offset opert1
foper1:	sub	di, offset opert1
	jmp	goper
foper2:	inc	si
	sub	di, offset opert2
	shr	di, 1
	add	di, noper1
goper:	lea	ax, [di+operpa]
	add	di, di
	add	di, ax
	mov	bl, [di]
	mov	di, [di+1]
	pop	eax
v_com:	pop	cx
	cmp	cx, bx
	jb	v_xcm
	pop	ecx
	xchg	eax, ecx
	pop	dx
	push	offset v_com
	push	dx
	ret
v_xcm:	cmp	bl, 1
	jbe	v_xit
	push	cx di eax bx
	jmp	v_lop
v_xit:	mov	[dword val], eax
	cmp	[ukp1], 1
	cmc
	jc	v_ret
wrange:	cmp	eax, 10000h
	cmc
	jnb	v_ret
	cmp	eax, -0ffffh
	jb	orange
	ret

brange:	cmp	eax, 100h
	jb	v_ret
	cmp	eax, -0ffh
	jb	orange
	ret

spauns:	call	spaces
getuns:	call	getval
	pushf
	jnc	getun1
	jpass1	getun2
getun1:	test	eax, eax
	js	orange
getun2:	popf
unsret:	ret

getpos:	call	getval
	jc	unknow
	test	eax, eax
	jg	unsret

orange:	error	e_range

mbrack:	error	e_brack

toobig:	error	e_nbig

; Procedury operatorow nie moga zmieniac bx ani di

v_sub:	neg	ecx		; -
v_add:	add	eax, ecx	; +
	jno	v_ret
oflow:	error	e_over

div0:	error	e_div0

v_mul:	mov	edx, ecx	; *
	xor	ecx, eax
	imul	edx
	test	ecx, ecx
	js	v_mu1
	test	edx, edx
	jnz	oflow
	test	eax, eax
	js	oflow
	ret
v_mu1:	inc	edx
	jnz	oflow
	test	eax, eax
	jns	oflow
	ret

v_div:	jecxz	div0		; /
	cdq
	idiv	ecx
	ret

v_mod:	jecxz	div0		; %
	cdq
	idiv	ecx
	sta	edx
v_ret:	ret

v_sln:	neg	ecx
v_sal:	test	ecx, ecx	; <<
	js	v_srn
	jz	v_ret
	cmp	ecx, 20h
	jb	v_sl1
	test	eax, eax
	jnz	oflow
	ret
v_sl1:	add	eax, eax
	jo	oflow
	loop	v_sl1
	ret

v_srn:	neg	ecx
v_sar:	test	ecx, ecx	; >>
	js	v_sln
	cmp	ecx, 20h
	jb	v_sr1
	mov	cl, 1fh
v_sr1:	sar	eax, cl
	ret

v_and:	and	eax, ecx	; &
	ret

v_or:	or	eax, ecx	; |
	ret

v_xor:	xor	eax, ecx	; ^
	ret

v_equ:	cmp	eax, ecx	; =
	je	v_one
v_zer:	xor	eax, eax
	ret
v_one:	mov	eax, 1
	ret

v_neq:	cmp	eax, ecx	; <> !=
	jne	v_one
	jmp	v_zer

v_les:	cmp	eax, ecx	; <
	jl	v_one
	jmp	v_zer

v_grt:	cmp	eax, ecx	; >
	jg	v_one
	jmp	v_zer

v_leq:	cmp	eax, ecx	; <=
	jle	v_one
	jmp	v_zer

v_geq:	cmp	eax, ecx	; >=
	jge	v_one
	jmp	v_zer

v_anl:	jecxz	v_zer		; &&
	test	eax, eax
	jz	v_ret
	jmp	v_one

v_orl:	or	eax, ecx	; ||
	jz	v_ret
	jmp	v_one

; Pobierz operand rozkazu i rozpoznaj tryb adresowania
getadr:	call	spaces
	lodsb
	xor	dx, dx
	cmp	al, '@'
	je	getadx
	cmp	al, '#'
	je	getaim
	cmp	al, '<'
	je	getaim
	cmp	al, '>'
	je	getaim
	mov	dl, 8
	cmp	al, '('
	je	getad1
	dec	si
	lodsw
	and	al, 0dfh
	mov	dl, 2
	cmp	ax, ':A'
	je	getad1
	inc	dx
	cmp	ax, ':Z'
	je	getad1
	dec	si
	dec	si
	xor	dx, dx
	
getad1:	push	dx
	call	getuns
	sbb	al, al
	jnz	getad2
	mov	al, [byte high val]
getad2:	pop	dx
	cmp	dl, 8
	jae	getaid
	cmp	dl, 2
	jae	getad3
	cmp	al, 1
	adc	dl, 2
getad3:	lodsw
	and	ah, 0dfh
	mov	bl, 2
	cmp	ax, 'X,'
	je	getabi
	mov	bl, 4
	cmp	ax, 'Y,'
	je	getabi
	dec	si
	dec	si
	jmp	getadx
getabi:	add	dl, bl
getaxt:	lodsb
	cmp	al, '+'
	je	getabx
	inc	bx
	cmp	al, '-'
	je	getabx
	dec	si
	jmp	getadx
getabx:	mov	dh, bl
getadx:	lda	dx
	mov	[word amod], ax
	ret

getaim:	cmp	al, '<'
	pushf
	call	getval
	popf
	jb	getai2
	je	getai1
	mov	al, ah
getai1:	movzx	eax, al
	mov	[dword val], eax
getai2:	mov	dx, 1
	jmp	getadx

getaid:	lodsb
	cmp	al, ','
	je	getaix
	cmp	al, ')'
	jne	mparen
	lodsw
	mov	dx, 709h
	cmp	ax, '0,'
	je	getadx
	xor	dh, dh
	mov	bl, 4
	and	ah, 0dfh
	cmp	ax, 'Y,'
	je	getaxt
	inc	dx
	dec	si
	dec	si
	jmp	getadx
getaix:	lodsw
	mov	dh, 6
	cmp	ax, ')0'
	je	getadx
	xor	dh, dh
	and	al, 0dfh
	cmp	ax, ')X'
	je	getadx
	jmp	ilchar
	
p_imp	=	savbyt

p_ads:	call	getadr
	mov	al, [cod]
	call	savbyt
	mov	al, 60h
	cmp	[cod], 18h
	je	p_as1
	mov	al, 0e0h
p_as1:	mov	[cod], al
	jmp	p_ac1

p_acc:	call	getadr
p_ac1:	mov	ax, [word amod]
	cmp	al, 7
	jne	acc1
	dec	[amod]
acc1:	cmp	ah, 6
	jb	acc3
	mov	ax, 0a2h
	je	acc2
	mov	al, 0a0h
acc2:	call	savwor
acc3:	mov	al, [amod]
	mov	bx, offset acctab
	xlat
	test	al, al
	jz	ilamod
	or	al, [cod]
	cmp	al, 89h
	jne	putsfx
ilamod:	error	e_amod

p_srt:	call	getadr
	cmp	al, 6
	jnb	ilamod
	cmp	al, 1
	je	ilamod
	mov	bx, offset srttab
	xlat
	or	al, [cod]
	cmp	al, 0c0h
	je	ilamod
	cmp	al, 0e0h
	je	ilamod
putsfx:	call	putcmd
	mov	al, [amod+1]
	mov	bx, offset sfxtab
	xlat
	test	al, al
	jnz	savbyt
putret:	ret
	
p_inw:	call	getadr
	cmp	al, 6
	jnb	ilamod
	sub	al, 2
	jb	ilamod
	mov	bx, offset inwtab
	xlat
	push	ax
	call	putcmd
	inc	[val]
	mov	ax, 03d0h
	test	[amod], 1
	jz	p_iw1
	dec	ah
p_iw1:	call	savwor
	pop	ax
	jmp	putsfx

p_ldi:	call	getadr
p_ld1:	mov	al, [amod]
	cmp	al, 1
	jb	ilamod
	cmp	al, 4
	jb	ldi1
	and	al, 0feh
	xor	al, [cod]
	cmp	al, 0a4h
	jne	ilamod
	mov	al, [amod]
ldi1:	mov	bx, offset lditab
	xlat
putcod:	or	al, [cod]
	jmp	putsfx

putcmd:	call	savbyt
	mov	al, [amod]
	mov	bx, offset lentab
	xlat
	cmp	al, 2
	jb	putret
	mov	eax, [dword val]
	jne	savwor
	jpass1	putcm1
	call	brange
putcm1:	jmp	savbyt

p_sti:	call	getadr
p_st1:	mov	al, [amod]
	cmp	al, 2
	jb	ilamod
	je	cod8
	cmp	al, 3
	je	cod0
	and	al, 0feh
	xor	al, [cod]
	cmp	al, 80h
	jne	ilamod
	or	[amod], 1
	mov	al, 10h
	jmp	putcod
cod8:	mov	al, 8
	jmp	putcod
cod0:	xor	al, al
	jmp	putcod

p_cpi:	call	getadr
	cmp	al, 1
	jb	ilamod
	cmp	al, 4
	jnb	ilamod
	cmp	al, 2
	jb	cod0
	je	cod8
	mov	al, 4
	jmp	putcod

p_bra:	call	getadr
	jpass1	bra1
	mov	ax, [val]
	sub	ax, [origin]
	add	ax, 7eh
	test	ah, ah
	jnz	toofar
	add	al, 80h
	mov	[byte val], al
bra1:	mov	al, [cod]
	call	savbyt
	mov	al, [byte val]
	jmp	savbyt

toofar:	cmp	ax, 8080h
	jae	toofa1
	sub	ax, 0ffh
	neg	ax
toofa1:	neg	ax
	mov	di, offset brout
	call	phword
	error	e_bra

p_jsr:	call	getadr
	mov	al, 20h
	jmp	p_abs

p_bit:	call	getadr
	cmp	al, 2
	mov	al, 2ch
	je	putcmd
	cmp	[amod], 3
	jne	ilamod
	mov	al, 24h
	jmp	putcmd

p_juc:	call	getadr
	mov	al, [cod]
	mov	ah, 3
	call	savwor
	jmp	p_jp1

p_jmp:	call	getadr
p_jp1:	cmp	[amod], 10
	je	chkbug
	jpass1	p_jpu
	cmp	[cod], 4ch
	je	p_jpu
	mov	ax, [val]
	sub	ax, [origin]
	add	ax, 80h
	test	ah, ah
	jnz	p_jpu
	push	si
	push	offset w_bras
	call	warln
	pop	si
p_jpu:	mov	al, 4ch
p_abs:	and	[amod], 0feh
	cmp	[amod], 2
	je	p_jpp
	jmp	ilamod
chkbug:	jpass1	p_jid
	cmp	[byte val], 0ffh
	jne	p_jid
	push	si
	push	offset w_bugjp
	call	warln
	pop	si
p_jid:	mov	al, 6ch
p_jpp:	jmp	putcmd

getops:	call	getadr
	lea	di, [op1]
	call	stop
	push	[word ukp1]
	call	getadr
	pop	[word ukp1]
	mov	[tempsi], si
	lea	di, [op2]
	call	stop
	movzx	bx, [cod]
	add	bx, offset movtab
ldop1:	lea	si, [op1]
ldop:	lodsd
	mov	[dword val], eax
	lodsw
	mov	[word amod], ax
	ret
stop:	mov	eax, [dword val]
	stosd
	mov	ax, [word amod]
	stosw
	ret

mcall1:	mov	al, [(movt bx).m_code]
	mov	[cod], al
	push	bx
	call	[(movt bx).m_vec]
	pop	bx
	ret

mcall2:	mov	al, [(movt bx+3).m_code]
	mov	[cod], al
	push	bx
	call	[(movt bx+3).m_vec]
	pop	bx
	ret

p_mvs:	call	getops
	call	mcall1
	lea	si, [op2]
	call	ldop
p_mvx:	call	mcall2
	mov	si, [tempsi]
	ret

p_mws:	call	getops
	mov	ax, [word amod]
	cmp	ax, 8
	jae	ilamod
	cmp	al, 1
	jne	p_mw1
	mov	[byte high val], 0
	mov	[word val+2], 0
p_mw1:	call	mcall1
	lea	si, [op2]
	call	ldop
	cmp	[word amod], 8
	jae	ilamod
	call	mcall2
	call	ldop1
	cmp	[amod], 1
	je	p_mwi
	inc	[val]
	jmp	p_mw2
p_mwi:	movzx	eax, [byte high val]
	cmp	[ukp1], ah	;0
	jnz	p_mwh
	cmp	al, [byte val]
	je	p_mw3
p_mwh:	mov	[dword val], eax
p_mw2:	call	mcall1
p_mw3:	lea	si, [op2]
	call	ldop
	inc	[val]
	jmp	p_mvx

p_opt:	call	spaces
	xor	cx, cx
opt1:	lodsw
	and	al, 0dfh
	cmp	al, 'L'
	je	optlst
	cmp	al, 'H'
	je	opthdr
	jcxz	opter
	dec	si
	dec	si
	ret
opter:	error	e_opt
optlst:	inc	cx
	cmp	ah, '+'
	je	optl1
	cmp	ah, '-'
	jne	opter
	or	[flist], m_lsto
	jmp	opt1
optl1:	jpass1	opt1
	and	[flist], not m_lsto
	jmp	opt1
opthdr:	inc	cx
	cmp	ah, '+'
	je	opth1
	cmp	ah, '-'
	jne	opter
	and	[flags], not (m_hdr+m_rqff)
	jmp	opt1
opth1:	bts	[word flags], b_hdr
	jc	opt1
	or	[flags], m_rorg
	jmp	opt1

p_ert:	call	spaval
	jpass1	equret
	test	eax, eax
	jz	equret
	error	e_user

p_equ:	mov	di, [labvec]
	test	di, di
	jz	nolabl
	mov	[(lab di).l_val], 0
	and	[(lab di).flags], not m_sign
	call	spaval
	mov	di, [labvec]
	jnc	equ1
	or	[(lab di).flags], m_ukp1
equ1:	mov	[(lab di).l_val], ax
	test	eax, eax
	jns	equ2
	or	[(lab di).flags], m_sign
equ2:	test	[flist], m_lsts
	jnz	equret
	sta	dx
	mov	di, offset lstorg
	mov	ax, ' ='
	test	eax, eax
	jns	equ3
	mov	ah, '-'
	neg	dx
equ3:	stosw
	lda	dx
	call	phword
	mov	[lstidx], di
equret:	ret

nolabl:	error	e_label

chkhon:	test	[flags], m_hdr
	jnz	equret
	error	e_hoff

p_org:	call	spaces
	and	[flags], not m_norg
	lodsw
	and	al, 0dfh
	cmp	ax, ':F'
	je	orgff
	cmp	ax, ':A'
	je	orgaf
	dec	si
	dec	si
	jmp	orget
orgff:	or	[flags], m_rqff
orgaf:	or	[flags], m_rorg
	call	chkhon
orget:	call	getuns
	jc	unknow
	mov	[origin], ax
	ret

p_rui:	call	chkhon
	mov	ah, 2
	mov	[origin], ax
	call	spauns
	jmp	savwor

valuco:	call	getval
	jc	unknow
	call	get
	cmp	al, ','
	jne	badsin
	mov	ax, [val]
	ret
badsin:	error	e_sin

p_dta:	call	spaces
dta1:	call	get
	and	al, 0dfh
	mov	[cod], al
	cmp	al, 'A'
	je	dtan1
	cmp	al, 'B'
	je	dtan1
	cmp	al, 'L'
	je	dtan1
	cmp	al, 'H'
	je	dtan1
	cmp	al, 'C'
	je	dtat1
	cmp	al, 'D'
	je	dtat1
	cmp	al, 'R'
	je	dtar1
	jmp	ilchar

dtan1:	lodsb
	cmp	al, '('
	jne	mparen

dtan2:	lodsd
	and	eax, 0ffdfdfdfh
	cmp	eax, '(NIS'
	jne	dtansi
	call	valuco
	mov	[sinadd], eax
	call	valuco
	mov	[sinamp], eax
	call	getpos
	mov	[sinsiz], ax
	mov	[sinmin], 0
	dec	ax
	mov	[sinmax], ax
	call	get
	cmp	al, ')'
	je	presin
	cmp	al, ','
	jne	badsin
	call	valuco
	test	eax, eax
	js	badsin
	mov	[sinmin], ax
	call	getuns
	jc	unknow
	cmp	ax, [sinmin]
	jb	badsin
	mov	[sinmax], ax
	lodsb
	cmp	al, ')'
	jne	mparen
presin:	finit
	fldpi
	fld	st
	faddp	st(1), st
	fidiv	[sinsiz]
gensin:	fild	[sinmin]
	fmul	st, st(1)
	fsin
	fimul	[sinamp]
	fiadd	[sinadd]
	fistp	[dword val]
	inc	[sinmin]
	mov	eax, [dword val]
	call	wrange
	jmp	dtasto
	
dtansi:	sub	si, 4
	call	getval
dtasto:	mov	al, [cod]
	cmp	al, 'A'
	je	dtana
	jpass1	dtans
	cmp	al, 'L'
	je	dtanl
	cmp	al, 'H'
	je	dtanh
	mov	eax, [dword val]
	call	brange
	jmp	dtans

dtana:	mov	ax, [val]
	call	savwor
	jmp	dtanx

dtanl:	mov	al, [byte low val]
	jmp	dtans

dtanh:	mov	al, [byte high val]

dtans:	call	savbyt
dtanx:	mov	ax, [sinmin]
	cmp	ax, [sinmax]
	jbe	gensin
	lodsb
	cmp	al, ','
	je	dtan2
	cmp	al, ')'
	je	dtanxt

mparen:	error	e_paren

unknow:	error	e_uknow

dtat1:	mov	di, offset tlabel
	call	rstr
	lodsb
	mov	ah, 80h
	cmp	al, '*'
	je	dtat2
	dec	si
	xor	ah, ah
dtat2:	push	si
	mov	si, dx
dtatm:	lodsb
	xor	al, ah
	cmp	[cod], 'D'
	jne	ascinx
	mov	dl, 60h
	and	dl, al
	jz	ascin1
	cmp	dl, 60h
	je	ascinx
	sub	al, 60h
ascin1:	add	al, 40h
ascinx:	push	ax cx
	call	savbyt
	pop	cx ax
	loop	dtatm
	pop	si
dtanxt:	lodsb
	cmp	al, ','
	je	dta1
	dec	si
	ret

; Zapisz liczbe rzeczywista
dtar1:	lodsb
	cmp	al, '('
	jne	mparen
dtar2:	xor	bx, bx
	xor	edx, edx
	xor	cx, cx
	call	getsgn
dreal1:	call	getdig
	jnc	dreal2
	cmp	al, '.'
	je	drealp
	test	bh, bh
	jnz	drealz
	jmp	ilchar
dreal2:	mov	bh, 1
	test	al, al
	jz	dreal1
	dec	cx
dreal3:	inc	cx
	call	putdig
	call	getdig
	jnc	dreal3
	cmp	al, '.'
	je	drealp
	and	al, 0dfh
	cmp	al, 'E'
	jne	drealf
dreale:	call	getsgn
	call	getdig
	jc	ilchar
	mov	ah, al
	call	getdig
	jnc	dreal4
	shr	ax, 8
dreal4:	aad
	add	di, di
	jnc	drealn
	neg	ax
drealn:	add	cx, ax
	jmp	drealf
dreal5:	test	edx, edx
	jnz	dreal9
	test	bl, bl
	jnz	dreal9
	dec	cx
dreal9:	call	putdig
drealp:	call	getdig
	jnc	dreal5
	and	al, 0dfh
	cmp	al, 'E'
	je	dreale
drealf:	test	edx, edx
	jnz	drealx
	test	bl, bl
	jnz	drealx
drealz:	xor	ax, ax
	xor	edx, edx
	jmp	dreals
drealx:	add	cx, 80h
	cmp	cx, 20h
	js	drealz
	cmp	cx, 0e2h
	jnb	toobig
	add	di, di
	rcr	cl, 1
	mov	al, 10h
	jc	dreal7
	cmp	bl, al
	mov	al, 1
	jb	dreal7
	shrd	edx, ebx, 4
	shr	bl, 4
	jmp	dreal8
dreal6:	shld	ebx, edx, 4
	shl	edx, 4
dreal7:	cmp	bl, al
	jb	dreal6
dreal8:	lda	cx
	mov	ah, bl
dreals:	rol	edx, 16
	push	edx
	call	savwor
	pop	ax
	xchg	ah, al
	call	savwor
	pop	ax
	xchg	ah, al
	call	savwor
	dec	si
	lodsb
	cmp	al, ','
	je	dtar2
	cmp	al, ')'
	jne	mparen
	jmp	dtanxt

putdig:	cmp	bl, 10h
	jnb	rlret
	shld	ebx, edx, 4
	shl	edx, 4
	add	dl, al
	ret

getsgn:	call	get
	cmp	al, '-'
	stc
	je	sgnret
	cmp	al, '+'
	clc
	je	sgnret
	dec	si
sgnret:	rcr	di, 1
rlret:	ret

getdig:	call	get
	cmp	al, '0'
	jb	rlret
	cmp	al, '9'+1
	cmc
	jb	rlret
	sub	al, '0'
	ret

p_icl:	call	rfname
	pop	ax
	push	di
	call	linend
	mov	dx, offset (icl).nam
	add	dx, [iclen]
	pop	di
	call	adasx
	jmp	opfile

p_ins:	call	rfname
	xor	eax, eax
	mov	[insofs], eax
	mov	[inslen], ax
	lodsb
	cmp	al, ','
	jne	p_ii2
	push	di
	call	getval
	jc	unknow
	mov	[insofs], eax
	lodsb
	cmp	al, ','
	jne	p_ii1
	call	getpos
	mov	[inslen], ax
	inc	si
p_ii1:	pop	di
p_ii2:	dec	si
	push	si
	call	fopen
	mov	dx, [word insofs]
	mov	cx, [word high insofs]
	mov	ax, 4200h
	jcxz	p_ip1
	mov	al, 2
p_ip1:	call	fsrce
p_in1:	mov	cx, [inslen]
	jcxz	p_in2
	test	ch, ch
	jz	p_in3
p_in2:	mov	cx, 256
p_in3:	mov	dx, offset tlabel
	call	fread
	jz	p_inx
	cwde
	mov	bx, [iclen]
	mov	bx, [(icl bx).prev]
	add	[(icl bx).line], eax
	mov	si, offset tlabel
	push	ax
	sta	cx
p_inp:	lodsb
	push	cx
	call	savbyt
	pop	cx
	loop	p_inp
	pop	ax
	cmp	[inslen], 0
	jz	p_in1
	sub	[inslen], ax
	jnz	p_in1
p_inx:	call	fclose
	pop	si
	cmp	[inslen], 0
	jz	rlret
	error	e_fshor

p_end:	pop	ax
	call	linend
	jmp	filend

shlelf:	shl	[elflag], 1
	jnc	cndret
	error	e_tmift

btself:	bts	[elflag], 0
	jnc	cndret
	error	e_eifex

p_ift:	call	spaval
	jc	unknow
	call	shlelf
	test	eax, eax
	jz	fliski
cndret:	ret

p_els:	cmp	[elflag], 1
	je	misift
	call	btself
fliski:	xor	[flags], m_skip
	ret

p_eif:	shr	[elflag], 1
	jnz	cndret
misift:	error	e_mift

; addressing modes:
; 0-@ 1-# 2-A 3-Z 4-A,X 5-Z,X 6-A,Y 7-Z,Y 8-(Z,X) 9-(Z),Y 10-(A)
lentab	db	1,2,3,2,3,2,3,2,2,2,3
acctab	db	0,9,0dh,5,1dh,15h,19h,19h,1,11h,0
srttab	db	0ah,0,0eh,6,1eh,16h
lditab	db	0,0,0ch,4,1ch,14h,1ch,14h
inwtab	db	0eeh,0e6h,0feh,0f6h
; pseudo-adr modes: 2-X+ 3-X- 4-Y+ 5-Y- 6-,0) 7-),0
sfxtab	db	0,0,0e8h,0cah,0c8h,088h,0,0

movtab	movt	<0a0h,p_ac1>,<080h,p_ac1>
	movt	<0a2h,p_ld1>,<086h,p_st1>
	movt	<0a0h,p_ld1>,<084h,p_st1>

comtab:	cmd	ADC60p_acc
	cmd	ADD19p_ads
	cmd	AND20p_acc
	cmd	ASL00p_srt
	cmd	BCC90p_bra
	cmd	BCSb0p_bra
	cmd	BEQf0p_bra
	cmd	BIT2cp_bit
	cmd	BMI30p_bra
	cmd	BNEd0p_bra
	cmd	BPL10p_bra
	cmd	BRK00p_imp
	cmd	BVC50p_bra
	cmd	BVS70p_bra
	cmd	CLC18p_imp
	cmd	CLDd8p_imp
	cmd	CLI58p_imp
	cmd	CLVb8p_imp
	cmd	CMPc0p_acc
	cmd	CPXe0p_cpi
	cmd	CPYc0p_cpi
	cmd	DECc0p_srt
	cmd	DEXcap_imp
	cmd	DEY88p_imp
	cmd	DTA01p_dta
	cmd	EIFffp_eif
	cmd	ELSffp_els
	cmd	ENDffp_end
	cmd	EOR40p_acc
	cmd	EQUffp_equ
	cmd	ERTffp_ert
	cmd	ICLffp_icl
	cmd	IFTffp_ift
	cmd	INCe0p_srt
	cmd	INIe3p_rui
	cmd	INS01p_ins
	cmd	INW01p_inw
	cmd	INXe8p_imp
	cmd	INYc8p_imp
	cmd	JCCb1p_juc
	cmd	JCS91p_juc
	cmd	JEQd1p_juc
	cmd	JMI11p_juc
	cmd	JMP4cp_jmp
	cmd	JNEf1p_juc
	cmd	JPL31p_juc
	cmd	JSR20p_jsr
	cmd	JVC71p_juc
	cmd	JVS51p_juc
	cmd	LDAa0p_acc
	cmd	LDXa2p_ldi
	cmd	LDYa0p_ldi
	cmd	LSR40p_srt
	cmd	MVA01p_mvs
	cmd	MVX07p_mvs
	cmd	MVY0dp_mvs
	cmd	MWA01p_mws
	cmd	MWX07p_mws
	cmd	MWY0dp_mws
	cmd	NOPeap_imp
	cmd	OPTffp_opt
	cmd	ORA00p_acc
	cmd	ORGffp_org
	cmd	PHA48p_imp
	cmd	PHP08p_imp
	cmd	PLA68p_imp
	cmd	PLP28p_imp
	cmd	ROL20p_srt
	cmd	ROR60p_srt
	cmd	RTI40p_imp
	cmd	RTS60p_imp
	cmd	RUNe1p_rui
	cmd	SBCe0p_acc
	cmd	SEC38p_imp
	cmd	SEDf8p_imp
	cmd	SEI78p_imp
	cmd	STA80p_acc
	cmd	STX86p_sti
	cmd	STY84p_sti
	cmd	SUB39p_ads
	cmd	TAXaap_imp
	cmd	TAYa8p_imp
	cmd	TSXbap_imp
	cmd	TXA8ap_imp
	cmd	TXS9ap_imp
	cmd	TYA98p_imp
comend:

operpa:	opr	1ret
	opr	5add
	opr	5sub
	opr	6mul
	opr	6div
	opr	6mod
	opr	6and
	opr	5or
	opr	5xor
	opr	4equ
	opr	4les
	opr	4grt
	opr	6sal
	opr	6sar
	opr	4leq
	opr	4geq
	opr	4neq
	opr	4neq
	opr	3anl
	opr	2orl

opert2	db	'<<>><=>=<>!=&&||'
noper2	=	($-opert2)/2
opert1	db	'+-*/%&|^=<>'
noper1	=	$-opert1

swilet	db	'TSOLIC'

hello	db	'X-Assembler 2.1� by Fox/Taquart',eot
hellen	=	$-hello-1
usgtxt	db	"Syntax: XASM source [options]",eol
	db	"/c         List false conditionals",eol
	db	"/i         Don't list included source",eol
	db	"/l[:fname] Generate listing",eol
	db	"/o:fname   Write object as 'fname'",eol
	db	"/s         Don't convert spaces to tabs in listing",eol
	db	"/t[:fname] List label table",eot
objtxt	db	'Writing object...',eot
lsttxt	db	'Writing listing...'
eoltxt	db	eot
srctxt	db	'Source: '
srctxl	=	$-srctxt
tabtxt	db	'Label table:',eol
tabtxl	=	$-tabtxt
lintxt	db	' lines of source assembled',eot
byttxt	db	' bytes written to object',eot
dectxt	db	10 dup(' '),'$'
wartxt	db	'WARNING: $'
w_bugjp	db	'Buggy indirect jump',eol
w_bras	db	'Branch would be sufficient',eol
errtxt	db	'ERROR: $'
e_open	db	'Can''t open file',eol
e_read	db	'Disk read error',eol
e_crobj	db	'Can''t write object',eol
e_wrobj	db	'Error writing object',eol
e_crlst	db	'Can''t write listing',eol
e_wrlst	db	'Error writing listing',eol
e_icl	db	'Too many files nested',eol
e_long	db	'Line too long',eol
e_uneol	db	'Unexpected eol',eol
e_char	db	'Illegal character',eol
e_twice	db	'Label declared twice',eol
e_inst	db	'Illegal instruction',eol
e_nbig	db	'Number too big',eol
e_xtra	db	'Extra characters on line',eol
e_label	db	'Label name required',eol
e_str	db	'String error',eol
e_orgs	db	'Too many ORGs',eol
e_paren	db	'Need parenthesis',eol
e_tlab	db	'Too many labels',eol
e_amod	db	'Illegal addressing mode',eol
e_bra	db	'Branch out of range by $'
brout	db	'     bytes',eol
e_sin	db	'Bad or missing sinus parameter',eol
e_spac	db	'Space expected',eol
e_opt	db	'Invalid options',eol
e_over	db	'Arithmetic overflow',eol
e_div0	db	'Divide by zero',eol
e_range	db	'Value out of range',eol
e_uknow	db	'Label not defined before',eol
e_undec	db	'Undeclared label',eol
e_fref	db	'Illegal forward reference',eol
e_wpar	db	'Use square brackets instead',eol
e_brack	db	'No matching bracket',eol
e_user	db	'User error',eol
e_tmift	db	'Too many IFTs nested',eol
e_eifex	db	'EIF expected',eol
e_mift	db	'Missing IFT',eol
e_meif	db	'Missing EIF',eol
e_norg	db	'No ORG specified',eol
e_fshor	db	'File is too short',eol
e_hoff	db	'Illegal when headers off',eol
e_crep	db	'Can''t repeat this directive',eol
e_quote	db	'Only simple command can be quoted',eol
e_rquot	db	'Recursive quote not supported',eol
e_mquot	db	'Missing ''}''',eol

exitcod	dw	4c00h
ohand	dw	nhand
lhand	dw	nhand
flags	db	m_norg+m_rorg+m_rqff+m_hdr
swits	db	0
sift	db	0
lines	dd	0
bytes	dd	0
srcen	dw	0
iclen	dw	t_icl
laben	dw	t_lab
pslab	dw	t_lab
elflag	dd	1
sinmin	dw	1
sinmax	dw	0
sinadd	dd	?
sinamp	dd	?
sinsiz	dw	?
flist	db	?
fslen	dw	?
times	dw	?
cmdvec	dw	?
quotsp	dw	?
insofs	dd	?
inslen	dw	?
origin	dw	?
curorg	dw	?
orgvec	dw	?
linlen	dw	?
lstidx	dw	?
labvec	dw	?
obyte	db	?
sbyte	db	?
op1	dd	?
	dw	?
op2	dd	?
	dw	?
tempsi	dw	?
errmsg	dw	?

var:
MACRO	bb	_name
_name&o	=	$-var
_name	equ	byte bp+_name&o
	db	?
	ENDM

MACRO	bw	_name
_name&o	=	$-var
_name	equ	word bp+_name&o
	dw	?
	ENDM

MACRO	bd	_name
_name&o	=	$-var
_name	equ	dword bp+_name&o
	dd	?
	ENDM

	bw	val
	dw	?
	bb	amod
	db	?
	bb	ukp1
	db	?
	bb	cod

var2	db	($-var) dup(?)

IFNDEF	compak
	undata
ENDIF

t_lab	db	l_lab dup(?)

	ENDS
	END	start