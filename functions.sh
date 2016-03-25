#!/usr/bin/bash

LANG=ja_JP.UTF-8

#よく使うもののまとめたもの
#あとサンプル
#一応bash限定

#shell内で標準入力を受け取る
#http://dsas.blog.klab.org/archives/51060184.html
#標準入力が、名前付きパイプならばcat -でそれを読んでそのまま出力し、そうでない場合はダミーのechoをする
function ShellPipe()
{
    if [[ -p /dev/stdin ]]; then
        cat -
    else
        echo -n
    fi
}

#本日日付YYYYMMDD
function NowDate_YYYYMMDD()
{
    date '+%Y%m%d'
    return $?
}

#昨日
function Yesterday_YYYYMMDD()
{
    date --date 'yesterday' '+%Y%m%d'
    return $?
}

#YYYMMDDからX日後
function GetDayAfter_YYYYMMDD()
{
    local num=${1:?"引数1に数値が設定されていません。"}
    date --date "$num + $2days" '+%Y%m%d'
    return $?
}

#YYYMMDDからX日前
function GetDayBefore_YYYYMMDD()
{
    local num=${1:?"引数1に数値が設定されていません。"}
    date --date "$num + $2days ago" '+%Y%m%d'
    return $?
}


#今月初日
function FirstDay_YYYYMMDD()
{
    date --date "`date '+%Y%m01'`" '+%Y%m%d'
    return $?
}

#今月末日
function EndDay_YYYYMMDD()
{
    #翌月から1日引く
    date --date "`date '+%Y%m01' -d '1 month'` 1 day ago" '+%Y%m%d'
    return $?
}

#先月末
function BeforeMonthEndDay_YYYMMDD()
{
    date --date "`date '+%Y%m01'` 1 day ago" '+%Y%m%d'
    return $?
}

#文字列分割 cut,splitを使わず文字列分割->高速
#パイプ入力
function ShellSplit()
{
    local OLDIFS=IFS
    local TEXT=`ShellPipe`
    IFS=','
    set -- $TEXT
    echo $1
    echo $2
    IFS=${OLDIFS}
}


#ログ出力
function log()
{
    local ATCH_ID=${1:?"引数1にプログラムIDが設定されていません。"}
    local ERR_LEVEL=${2:?"引数2にエラーレベルが設定されていません。"}
    local MSG_ID=${3:?"引数3にメッセージIDが設定されていません。"}
    local MSG=${4:?"引数4にメッセージが設定されていません。"}
    local OUTPUT_FILE=${5:?"引数4に出力先が設定されていません。"}
    
    local MSG_HEADER_FMT="%Y/%m/%d %H:%M:%S.000:"
    local MSG_HEADER=`date "+${MSG_HEADER_FMT}"`
    local MSG_FOOTER="${BATCH_ID}: : : ${MSG_ID}: ${MSG}"
    
    case $ERR_LEVEL in
        "DEBUG") echo "${MSG_HEADER} DEBUG: ${MSG_FOOTER}" >> ${OUTPUT_FILE};;
        "INFO") echo "${MSG_HEADER} INFO: ${MSG_FOOTER}" >> ${OUTPUT_FILE};;
        "WARN") echo "${MSG_HEADER} WARN: ${MSG_FOOTER}" >> ${OUTPUT_FILE};;
        "ERROR") echo "${MSG_HEADER} ERROR: ${MSG_FOOTER}" | logger -p user.err > /dev/null
             echo "${MSG_HEADER} ERROR: ${MSG_FOOTER}" >> ${OUTPUT_FILE};;
        *) echo "ログレベルが間違っています。"
           return 1;
    esac
}

#ログ出力その2
function log2()
{
    readonly LOGFILE="/tmp/${0##*/}.log"
    
    readonly PROCNAME=${0##*/}
    function log() {
        local fname=${BASH_SOURCE[1]##*/}
        echo -e "$(date '+%Y-%m-%dT%H:%M:%S') ${PROCNAME} (${fname}:${BASH_LINENO[0]}:${FUNCNAME[1]}) $@" | tee -a ${LOGFILE}
    }
}


#sshによるファイル存在確認 ノンパス必要
#  引数
#  　第１引数： ホスト名
#  　第２引数： ユーザ名
#  　第３引数： ファイル名（フルパス）
#  ファイルが存在する場合：
#  	返値：0，標準出力に文字列"OK"を返す。
#  ファイルが存在しない場合：
#  	返値: 0，標準出力に文字列"NG"を返す。
#  そのほか、システム異常でチェックに失敗した場合：
#  	返値：1，標準エラー出力にエラー内容を出力。
function SSHFileCheck()
{
    if [ $# -ne 3 ]
    then
	    echo "usage : SSHFileCheck host user check-file" ;
	    return 1;
    fi
    
    local HOST=$1
    local USER=$2
    local FILE=$3
    
    local FLG=`ssh -l $USER $HOST "if test -f $FILE
then
	echo 0
else
	echo 1
fi"`
    
    if [ $FLG ]
    then
	    :
    else
	    return 1
    fi
    
    case $FLG in
        0) echo OK ;;
        1) echo NG ;;
    esac
    
    return 0
}


#SSHでリモートのファイルを削除する
function SSHFileDel()
{
    if [ $# -ne 3 ]
    then
        echo "usage : SSHFileDel host user file" ;
        return 1;
    fi
    
    local HOST=$1
    local USER=$2
    local FILE=$3
    
    local FLG=`ssh -l $USER $HOST "if rm $FILE
then
	echo 0
else
	echo 1
fi"`
    
    if [ $FLG ]
    then
        return $FLG;
    else
        return 1 ;
    fi
}



#sshによるファイル取得 ノンパス必要
#これは内部関数
function _SSHFileGet()
{
	if scp -q $OPTION $USER@$HOST:$FROM $TO
	then
		:
	else
		return 1 ;
	fi
    
	local FROMSIZE=`ssh -l $USER $HOST "ls -l $FROM" | awk '{print $5}'`
	local TOSIZE=`ls -l $TO | awk '{print $5}'`
    
	if [ $FROMSIZE -ne $TOSIZE ]
	then
		return 1 ;
	fi
	    return 0 ;
}
function SSHFileGet()
{
    if [ $# -ne 4 -a $# -ne 5 ]
    then
	    echo "usage : SSHFileGet host user from-file to-file [scp-option]" ;
	    return 1;
    fi
    
    local HOST=$1
    local USER=$2
    local FROM=$3
    local TO=$4
    local OPTION=$5
    
    if _SSHFileGet
    then
	    :
    else
	    if _SSHFileGet
	    then
		    :
	    else
		    echo "_SSHFileGet ERR : HOST=$HOST FROM=$FROM TO=$TO OPTION=$OPTION" >&2 ;
		    return 1;
	    fi
    fi
    
    return 0;
}

#SSHによるファイルリストの取得
function SSHFileList()
{
    if [ $# -ne 3 ]
    then
	    echo "usage : SSHFileList host user check-file" ;
	    return 1;
    fi
    
    local HOST=$1
    local USER=$2
    local FILE=$3
    
    ssh -l $USER $HOST "ls -1 ${FILE}"
    return ?
}

function SSHFileMove()
{
    if [ $# -ne 4 ]
    then
	    echo "usage : $0 host user check-file" ;
	    return 1;
    fi
    
    local HOST=$1
    local USER=$2
    local FILE=$3
    local TOFILE=$4
    
    ssh -l $USER $HOST "mv -b $FILE $TOFILE"
}


#SSHによるファイルの送信
function _SSHFilePut()
{
    if scp -q $OPTION $FROM $USER@$HOST:$TO
	then
		:
	else
		return 1 ;
	fi
    
	local FROMSIZE=`ls -l $FROM | awk '{print $5}'`
	local TOSIZE=`ssh -l $USER $HOST "ls -l $TO" | awk '{print $5}'`

	if [ $FROMSIZE -ne $TOSIZE ]
	then
		return 1 ;
	fi
	return 0 ;
}
function SSHFilePut()
{
    if [ $# -ne 4 -a $# -ne 5 ]
    then
	    echo "usage : SSHFilePut host user from-file to-file [scp-option]" ;
	    return 1;
    fi
    
    local HOST=$1
    local USER=$2
    local FROM=$3
    local TO=$4
    local OPTION=$5
    
    
    if _SSHFilePut
    then
	    :
    else
	    if _SSHFilePut
	    then
		    :
	    else
		    echo "SSHFilePut ERR : HOST=$HOST FROM=$FROM TO=$TO OPTION=$OPTION" >&2 ;
		    return 1;
	    fi
    fi
    
    return 0;
}

#BashでHTTPRequest $1:ホスト $2:パス
function HTTPRequest()
{
    exec 8<> /dev/tcp/$1/80
    echo -e "GET $2 HTTP/1.0\n\n" >&8
    cat <&8
}

#sed置換サンプル.タダのサンプルです
function SedReplace()
{
    echo $1 | sed -e 's/<key>\(....\).*<\/key>/<key>\1*<\/key>/g'
}

#CSV処理sample。あくまでもサンプル。項目数を自動化出来れば...
function csv()
{
    local OLDIFS=IFS
    IFS=$','
    local col=(`echo "$1"`)
    
    echo \
        ${col[0]},\
        ${col[1]},\
        ${col[2]},\
        ${col[3]},\
        ${col[4]},\
        ${col[5]},\
        ${col[6]},\
        ${col[7]},\
        ${col[8]},\
        ${col[9]},\
        ${col[10]}
    IFS=${OLDIFS}
}


#最初の2文字を得る
function First2Char()
{
    echo "`echo $1 |cut -c1-2`"
}



##引数があったらそれを使い、なかったら当日日付
function ArgDate()
{
    DATE=${1:-"`date +%Y%m%d`"}
    echo ${DATE}
}



#Bashだけでメール送信。日本語もOK utf8
function _BashMailSend() {
    local from=$1
    local to=$2
    local inputEncoding="utf-8"
    local outputEncoding="iso-2022-jp"
    local subjectHead="=?${outputEncoding}?B?"
    local subjectBody="`echo "$3" | iconv -f ${inputEncoding} -t ${outputEncoding} | base64 | tr -d '\n'`"
    local subjectTail="?="
    local subject="${subjectHead}${subjectBody}${subjectTail}"
    local contents="`echo -e $4 | iconv -f ${inputEncoding} -t ${outputEncoding}`"

    exec 8<> /dev/tcp/$5/25
    echo "EHLO `hostname`" >&8
    sleep 1
#    echo "auth login" >&8
#    echo "$user" >&8
#    echo "$pass" >&8
    echo "mail from: ${from}" >&8
    echo "rcpt to: ${to}" >&8
    echo "data" >&8
    echo "To: ${to}" >&8
    echo "From: ${from}" >&8
    echo "Subject: ${subject}" >&8
    echo "${contents}" >&8
    echo "." >&8
    echo "quit" >&8
    cat <&8
}
function BashMailSend()
{
    local from=${1:?"引数1 FROMが未設定"}
    local to=${2:?"引数2 TOが未設定"}
    local subject=${3:?"引数3 SUBJECTが未設定"}
    local contents=${4:?"引数4 本文が未設定"}
    local smtp=${5:?"引数5 smtpが未設定"}
    _BashMailSend $from $to $subject $contents $smtp
    return $?
}



#PWの入力サンプル。端末にPWを表示させたく無いときなどの
function InputPW()
{
    echo "PWを入力してください"
    stty -echo
    read ___IDPW
    stty echo
    echo ${___IDPW}
}


#FTP Binary put
function ftpcmd()
{
    ftp -n << FTP_END
  open $1
  user $2
  bin
  put $3
quit
FTP_END
}


#OPENSSLの暗号化
function opensslEncode()
{
    echo "$1" | openssl des3 -e -a -pass "pass:$2"
}


#OPENSSLの複合化
function opensslDecode()
{
    echo "$1" | openssl des3 -d -a -pass "pass:$2"
}


#繰り返し読み込む場合のサンプル
function while_read_sampe()
{
    while read i
    do
        echo $i
    done
}



#パスワード付きのzipを解凍する。expectのサンプルでもある
function PassedZipUnPack()
{
    local zipfile=${1:?"引数1 zipfileが未設定"}
    local pass=${2:?"引数2 passwordが未設定"}
    expect -c "
set timeout 5
spawn unzip -o ${$zipfile}
expect \"password: \"
send \"${$pass}\r\"
interact
"
    return $?
}


#SSL上でTELNETみたいな事をやる
function SSLtelnet()
{
    local HOST=${1:?"input host"}
    local PORT=${2:?"input port"}
    openssl s_client -connect $HOST:$PORT -state
}

#自己署名によるSSLサーバを立ち上げる portは8443
function StartSelfSignedSSLServer()
{
    local SERVERKEY=`mktemp`
    local SERVERCRT=`mktemp`
    openssl genrsa -out ${SERVERKEY} 1024
    openssl req -new -x509 -days 3650 -key ${SERVERKEY} -out ${SERVERCRT}
    cat ${SERVERKEY} >> ${SERVERCRT}
    rm ${SERVERKEY}
    echo "${SERVERCRT}は後で消してね"
    #本当はtrap 'rm ${SERVERCRT}' EXITとかでやりたい
    openssl s_server -cert ${SERVERCRT} -accept 8443
}

#BASHの文法チェック
function BashShellCheck()
{
    bash -n $1
}

#改行コードをCRLF->LF
function CRLFtoLF()
{
    echo `ShellPipe` | perl -pe "s/\r\n/\n/g"
}

#改行コードをLF->CRLF
function  LFtoCRLF()
{
    echo `ShellPipe` | perl -pe "s/\n/\r\n/g"
}

#SOAレコードを引く
function dig_soa()
{
    dig $i soa
}

#wgetによるポスト
function wget_post()
{
    URL=${1:?"引数1 URLが未設定"}
    POST=${2:?"引数2 POSTデータが未設定"}

    wget --post-data=${POST} ${URL} -O -
    return $?
}
