* split - split a file
*
* Itagaki Fumihiko 27-Feb-93  Create.
* 1.0
*
* Usage: split [ -cvZ ] [ -<N>[ckl] ] [ -- ] [ <�t�@�C��> [ <�o�̓x�[�X��> ] ]

.include doscall.h
.include limits.h
.include stat.h
.include chrcode.h

.xref DecodeHUPAIR
.xref issjis
.xref isdigit
.xref atou
.xref strlen
.xref stpcpy
.xref strfor1
.xref contains_dos_wildcard
.xref strip_excessive_slashes

STACKSIZE	equ	2048

OUTBUF_SIZE	equ	8192

DEFAULT_COUNT	equ	1000

CTRLD	equ	$04
CTRLZ	equ	$1A

FLAG_c		equ	0	*  -c
FLAG_v		equ	1	*  -v
FLAG_Z		equ	2	*  -Z
FLAG_byte_unit	equ	3

.text

start:
		bra.s	start1
		dc.b	'#HUPAIR',0
start1:
		lea	stack_bottom(pc),a7		*  A7 := �X�^�b�N�̒�
		lea	$10(a0),a0			*  A0 : PDB�A�h���X
		move.l	a7,d0
		sub.l	a0,d0
		move.l	d0,-(a7)
		move.l	a0,-(a7)
		DOS	_SETBLOCK
		addq.l	#8,a7
	*
		move.l	#-1,stdin
	*
	*  �������ъi�[�G���A���m�ۂ���
	*
		lea	1(a2),a0			*  A0 := �R�}���h���C���̕�����̐擪�A�h���X
		bsr	strlen				*  D0.L := �R�}���h���C���̕�����̒���
		addq.l	#1,d0
		bsr	malloc
		bmi	insufficient_memory

		movea.l	d0,a1				*  A1 := �������ъi�[�G���A�̐擪�A�h���X
	*
	*  �������f�R�[�h���C���߂���
	*
		moveq	#0,d6				*  D6.W : �G���[�E�R�[�h
		bsr	DecodeHUPAIR			*  �������f�R�[�h����
		movea.l	a1,a0				*  A0 : �����|�C���^
		move.l	d0,d7				*  D7.L : �����J�E���^
		moveq	#0,d5				*  D5.B : �t���O
		move.l	#DEFAULT_COUNT,count
decode_opt_loop1:
		tst.l	d7
		beq	decode_opt_done

		cmpi.b	#'-',(a0)
		bne	decode_opt_done

		tst.b	1(a0)
		beq	decode_opt_done

		subq.l	#1,d7
		addq.l	#1,a0
		move.b	(a0)+,d0
		bsr	isdigit
		beq	decode_count

		cmp.b	#'-',d0
		bne	decode_opt_loop2

		tst.b	(a0)+
		beq	decode_opt_done

		subq.l	#1,a0
decode_opt_loop2:
		moveq	#FLAG_c,d1
		cmp.b	#'c',d0
		beq	set_option

		moveq	#FLAG_v,d1
		cmp.b	#'v',d0
		beq	set_option

		moveq	#FLAG_Z,d1
		cmp.b	#'Z',d0
		beq	set_option

		moveq	#1,d1
		tst.b	(a0)
		beq	bad_option_1

		bsr	issjis
		bne	bad_option_1

		moveq	#2,d1
bad_option_1:
		move.l	d1,-(a7)
		pea	-1(a0)
		move.w	#2,-(a7)
		lea	msg_illegal_option(pc),a0
		bsr	werror_myname_and_msg
		DOS	_WRITE
		lea	10(a7),a7
		bra	usage

set_option:
		bset	d1,d5
set_option_done:
		move.b	(a0)+,d0
		bne	decode_opt_loop2
		bra	decode_opt_loop1

decode_count:
		subq.l	#1,a0
		bsr	atou
		bne	bad_count

		bclr	#FLAG_byte_unit,d5
		move.b	(a0)+,d0
		beq	decode_count_ok

		cmp.b	#'l',d0
		beq	decode_count_unit_ok

		bset	#FLAG_byte_unit,d5
		cmp.b	#'c',d0
		beq	decode_count_unit_ok

		cmp.b	#'k',d0
		bne	bad_count

		cmp.l	#$400000,d1
		bhs	bad_count

		lsl.l	#8,d1
		lsl.l	#2,d1
decode_count_unit_ok:
		tst.b	(a0)+
		bne	bad_count
decode_count_ok:
		move.l	d1,count
		bne	decode_opt_loop1
bad_count:
		lea	msg_illegal_count(pc),a0
		bsr	werror_myname_and_msg
		bra	usage

decode_opt_done:
	*
	*  ���̓o�b�t�@�Ƃ��čő僁�������m�ۂ���
	*
		move.l	#$00ffffff,d0
		bsr	malloc
		sub.l	#$81000000,d0
		cmp.l	#1024,d0
		blo	insufficient_memory

		move.l	d0,inpbuf_size
		bsr	malloc
		bmi	insufficient_memory

		move.l	d0,inpbuf
	*
	*  �W�����͂�؂�ւ���
	*
		clr.w	-(a7)				*  �W�����͂�
		DOS	_DUP				*  ���������n���h��������͂��C
		addq.l	#2,a7
		move.l	d0,stdin
		bmi	start_do_files

		clr.w	-(a7)
		DOS	_CLOSE				*  �W�����͂̓N���[�Y����D
		addq.l	#2,a7				*  �������Ȃ��� ^C �� ^S �������Ȃ�
start_do_files:
	*
	*  �J�n
	*
		lea	default_basename(pc),a1
		subq.l	#1,d7
		bcs	do_stdin
		beq	do_arg

		subq.l	#1,d7
		bhi	too_many_args

		movea.l	a0,a1
		bsr	strfor1
		bsr	strlen
		cmp.l	#MAXHEAD+MAXFILE,d0
		bhi	too_long_basename

		exg	a0,a1
do_arg:
		cmpi.b	#'-',(a0)
		bne	do_file

		tst.b	1(a0)
		bne	do_file
do_stdin:
		lea	msg_stdin(pc),a0
		move.l	stdin,d1
		bra	do_file_1

do_file:
		bsr	strip_excessive_slashes
		clr.w	-(a7)
		move.l	a0,-(a7)
		DOS	_OPEN
		addq.l	#6,a7
		move.l	d0,d1
do_file_1:
		lea	msg_open_fail(pc),a2
		bmi	werror_exit_2
							*  D1.L == input handle
		move.l	a0,input_name
		sf	eof
		clr.l	byte_remain
	*
	*  ���͂�trunc���ׂ����ǂ������肷��
	*
		btst	#FLAG_Z,d5
		sne	ignore_from_ctrlz
		sf	ignore_from_ctrld
		move.w	d1,-(a7)
		clr.w	-(a7)
		DOS	_IOCTRL
		addq.l	#4,a7
		tst.l	d0
		bmi	do_file_2

		btst	#7,d0
		beq	do_file_2			*  block

		btst	#5,d0
		bne	do_file_2			*  raw

		st	ignore_from_ctrlz
		st	ignore_from_ctrld
do_file_2:
	*
	*  �ŏ��̏o�̓t�@�C�������쐬����
	*
		lea	output_name(pc),a0
		bsr	stpcpy
		lea	str_dot000(pc),a1
		bsr	stpcpy
		movea.l	a0,a3				*  A3 : bottom of output_name
	*
	*  �����J�n
	*
do_file_loop:
		moveq	#-1,d2				*  D2.L : �o�̓t�@�C���n���h���i-1 == ���쐬 ... �ŏ���flush���ɍ쐬����j
		move.l	#OUTBUF_SIZE,outbuf_free
		lea	outbuf(pc),a5			*  A5 : �o�̓o�b�t�@�̃|�C���^
		move.l	count,d3			*  D3.L : �����o���J�E���g
output_one_loop:
		bsr	getc
		bmi	output_one_done

		bsr	putc
		btst	#FLAG_byte_unit,d5
		bne	decrement_count

		cmp.b	#LF,d0
		bne	output_one_loop
decrement_count:
		subq.l	#1,d3
		bne	output_one_loop
output_one_done:
		move.l	d0,-(a7)
		bsr	flush_outbuf
		tst.l	d2
		bmi	output_close_done

		move.w	d2,-(a7)
		DOS	_CLOSE
		addq.l	#2,a7
		tst.l	d0
		bmi	write_fail
output_close_done:
		move.l	(a7)+,d0
		bmi	all_done

		movea.l	a3,a0
make_next_name:
		cmpi.b	#'.',-(a0)
		beq	too_many_outputs

		addq.b	#1,(a0)
		cmpi.b	#'9',(a0)
		bls	do_file_loop

		move.b	#'0',(a0)
		bra	make_next_name

all_done:
exit_program:
		move.l	stdin,d0
		bmi	exit_program_1

		clr.w	-(a7)				*  �W�����͂�
		move.w	d0,-(a7)			*  ����
		DOS	_DUP2				*  �߂��D
		DOS	_CLOSE				*  �����̓N���[�Y����D
exit_program_1:
		move.w	d6,-(a7)
		DOS	_EXIT2


too_many_outputs:
		lea	msg_too_many_outputs(pc),a0
		bsr	werror_myname_and_msg
		bra	exit_2

too_long_basename:
		bsr	werror_myname_and_msg
		lea	msg_too_long_basename(pc),a0
		bra	werror_exit_1

too_many_args:
		lea	msg_too_many_args(pc),a0
		bsr	werror_myname_and_msg
usage:
		lea	msg_usage(pc),a0
werror_exit_1:
		bsr	werror
		moveq	#1,d6
		bra	exit_program
*****************************************************************
getc:
		tst.l	byte_remain
		bne	getc_1

		tst.b	eof
		bne	read_done

		movea.l	inpbuf,a2
		move.l	inpbuf_size,-(a7)
		move.l	a2,-(a7)
		move.w	d1,-(a7)
		DOS	_READ
		lea	10(a7),a7
		move.l	d0,byte_remain
		bmi	read_fail

		tst.b	ignore_from_ctrlz
		beq	trunc_ctrlz_done

		moveq	#CTRLZ,d0
		bsr	trunc
trunc_ctrlz_done:
		tst.b	ignore_from_ctrld
		beq	trunc_ctrld_done

		moveq	#CTRLD,d0
		bsr	trunc
trunc_ctrld_done:
read_done:
		move.l	byte_remain,d0
		beq	getc_eof
getc_1:
		moveq	#0,d0
		move.b	(a2)+,d0
		sub.l	#1,byte_remain
		cmp.b	d0,d0
		rts

getc_eof:
		clr.l	byte_remain
		st	eof
		moveq	#-1,d0
		rts

read_fail:
		bsr	flush_outbuf
		movea.l	input_name,a0
		lea	msg_read_fail(pc),a2
werror_exit_2:
		bsr	werror_myname_and_msg
		movea.l	a2,a0
		bsr	werror
exit_2:
		moveq	#2,d6
		bra	exit_program
*****************************************************************
trunc:
		tst.l	byte_remain
		beq	trunc_return

		move.l	d1,-(a7)
		movea.l	inpbuf,a0
		movea.l	a0,a1
		move.l	byte_remain,d1
trunc_find_loop:
		cmp.b	(a0)+,d0
		beq	trunc_found

		subq.l	#1,d1
		bne	trunc_find_loop
		bra	trunc_done

trunc_found:
		subq.l	#1,a0
		move.l	a0,d0
		sub.l	a1,d0
		move.l	d0,byte_remain
		st	eof
trunc_done:
		move.l	(a7)+,d1
trunc_return:
		rts
*****************************************************************
putc:
		tst.l	outbuf_free
		bne	putc_1

		bsr	flush_outbuf
putc_1:
		move.b	d0,(a5)+
		subq.l	#1,outbuf_free
putc_done:
		rts
*****************************************************************
flush_outbuf:
		move.l	d0,-(a7)
		move.l	#OUTBUF_SIZE,d0
		cmp.l	outbuf_free,d0
		beq	flush_done

		tst.l	d2
		bpl	do_flush_outbuf

		*  1��ڂ�flush ... �t�@�C�����쐬����

			lea	output_name(pc),a0
			bsr	contains_dos_wildcard
			bne	create_fail

			btst	#FLAG_c,d5
			beq	do_create

			move.w	#MODEVAL_ALL,-(a7)
			move.l	a0,-(a7)
			pea	filesbuf(pc)
			DOS	_FILES
			lea	10(a7),a7
			tst.l	d0
			bpl	file_exists
do_create:
			move.w	#$20,-(a7)		*  �ʏ�̃t�@�C�����[�h��
			move.l	a0,-(a7)		*  �o�͐�t�@�C����
			DOS	_CREATE			*  �V�K�쐬����
			addq.l	#6,a7
			move.l	d0,d2			*  D2.L : output handle
			bmi	create_fail

			btst	#FLAG_v,d5
			beq	do_flush_outbuf

			move.l	a0,-(a7)
			DOS	_PRINT
			addq.l	#4,a7
			pea	msg_newline(pc)
			DOS	_PRINT
			addq.l	#4,a7
do_flush_outbuf:
		*  �����o��
		move.l	#OUTBUF_SIZE,d0
		sub.l	outbuf_free,d0
		move.l	d0,-(a7)
		pea	outbuf(pc)
		move.w	d2,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		tst.l	d0
		bmi	write_fail

		cmp.l	-4(a7),d0
		blo	write_fail

		lea	outbuf(pc),a5
		move.l	#OUTBUF_SIZE,d0
		move.l	d0,outbuf_free
flush_done:
		move.l	(a7)+,d0
		rts

file_exists:
		lea	msg_file_exists(pc),a2
		bra	werror_exit_2

create_fail:
		lea	output_name(pc),a0
		lea	msg_create_fail(pc),a2
		bra	werror_exit_2

write_fail:
		lea	output_name(pc),a0
		lea	msg_write_fail(pc),a2
werror_exit_3:
		bsr	werror_myname_and_msg
		movea.l	a2,a0
		bsr	werror
		bra	exit_3
*****************************************************************
insufficient_memory:
		lea	msg_no_memory(pc),a0
		bsr	werror_myname_and_msg
exit_3:
		moveq	#3,d6
		bra	exit_program
*****************************************************************
werror_myname:
		move.l	a0,-(a7)
		lea	msg_myname(pc),a0
		bsr	werror
		movea.l	(a7)+,a0
		rts
*****************************************************************
werror_myname_and_msg:
		bsr	werror_myname
werror:
		movem.l	d0/a1,-(a7)
		movea.l	a0,a1
werror_1:
		tst.b	(a1)+
		bne	werror_1

		subq.l	#1,a1
		suba.l	a0,a1
		move.l	a1,-(a7)
		move.l	a0,-(a7)
		move.w	#2,-(a7)
		DOS	_WRITE
		lea	10(a7),a7
		movem.l	(a7)+,d0/a1
		rts
*****************************************************************
malloc:
		move.l	d0,-(a7)
		DOS	_MALLOC
		addq.l	#4,a7
		tst.l	d0
		rts
*****************************************************************
.data

	dc.b	0
	dc.b	'## split 1.0 ##  Copyright(C)1993 by Itagaki Fumihiko',0

msg_myname:		dc.b	'split: ',0
msg_no_memory:		dc.b	'������������܂���',CR,LF,0
msg_too_many_outputs:	dc.b	'�o�̓t�@�C���������߂��܂�',CR,LF,0
msg_open_fail:		dc.b	': �I�[�v���ł��܂���',CR,LF,0
msg_create_fail:	dc.b	': �쐬�ł��܂���',CR,LF,0
msg_file_exists:	dc.b	': �t�@�C�������݂��Ă��܂�',CR,LF,0
msg_too_long_basename:	dc.b	': �o�̓x�[�X�������߂��܂�',CR,LF,0
msg_read_fail:		dc.b	': ���̓G���[',CR,LF,0
msg_write_fail:		dc.b	': �o�̓G���[',CR,LF,0
msg_illegal_option:	dc.b	'�s���ȃI�v�V���� -- ',0
msg_illegal_count:	dc.b	'�J�E���g�̎w�肪�s���ł�',0
msg_too_many_args:	dc.b	'���������߂��܂�',0
msg_usage:		dc.b	CR,LF,'�g�p�@:  split [-cvZ] [-<N>[ckl]] [--] [ <�t�@�C��> [<�o�̓x�[�X��>] ]'
msg_newline:		dc.b	CR,LF,0
msg_stdin:		dc.b	'- �W������ -',0
default_basename:	dc.b	'x',0
str_dot000:		dc.b	'.000',0
*****************************************************************
.bss

.even
stdin:			ds.l	1
inpbuf:			ds.l	1
inpbuf_size:		ds.l	1
outbuf_free:		ds.l	1
count:			ds.l	1
byte_remain:		ds.l	1
input_name:		ds.l	1
output_name:		ds.b	MAXPATH+1
.even
filesbuf:		ds.b	STATBUFSIZE
ignore_from_ctrlz:	ds.b	1
ignore_from_ctrld:	ds.b	1
eof:			ds.b	1
outbuf:			ds.b	OUTBUF_SIZE

		ds.b	STACKSIZE
.even
stack_bottom:
*****************************************************************

.end start
