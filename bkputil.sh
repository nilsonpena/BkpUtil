#!/bin/bash - 
#===============================================================================
#
#          FILE: bkputil.sh
# 
#         USAGE: ./bkputil.sh file.conf
# 
#   DESCRIPTION: Script que gerencia backup incremental com o TAR 
# 
#       OPTIONS: ---
#  REQUIREMENTS: ---
#          BUGS: ---
#         NOTES: ---
#        AUTHOR: Nilson Pena (), nilsonpena@gmail.com
#  ORGANIZATION: 
#       CREATED: 22-02-2012 09:28:55 BRT
#      REVISION:  ---
#===============================================================================

set -o nounset                              # Treat unset variables as an error

# Testa a existência de parâmetros na inicialização do script
if [ "$*" = "" ]
then
	echo "ERRO!!! É necessários informar o nome do arquivo de configuração como parâmetro. Backup Abortado"
	exit
fi
# Armazena o path do script
DIR_SCRIPT=$(dirname $0)

# Coloca o path do script no nome do arquivo passado como parâmetro
# isso obriga salvar o arquivo .conf no mesmo local do script.
CONFIG_FILE="$DIR_SCRIPT/$1"

# Testa a existência do arquivo de configuração dentro do diretório do script
if [ ! -e $CONFIG_FILE ]
	then
		echo "ERRO!!! O arquivo de configuração $1 deve ficar no mesmo diretório do script. Backup abortado"			
		exit
fi

# Remove a extenção do arquivo de configuração, guardando apenas a parte principal do nome
CONFIG_NAME=$(echo $1 | cut -f1 -d.)

# Array que armazena os nomes das variáveis que vão ser buscadas no
# arquivo de configuração
CHAVES=( FSHD LABEL_HD DESTINATARIO LISTA_BACKUP NAO_FAZER_BACKUP N_OLD )

# Armazena a quantidade de elementos existentes na array CHAVES
QTD_CHAVES=${#CHAVES[*]}
	# Percorre o arquivo de configuração $CONFIG_FILE buscando os valores das variáveis setadas na Array CHAVES
        for ((i=0; i<"$QTD_CHAVES"; i++))
                do
			# Seta os valores vindos do arquivo de configuração nas variáveis que vão ser utilizadas no script
                        eval ${CHAVES[$i]}=\"$(cat $CONFIG_FILE | egrep ^${CHAVES[$i]}= | cut -f2 -d\")\"
                done
								
# Seta o path do dispositivo de montagem do hd
PATH_HD="/dev/disk/by-label/$LABEL_HD"
# Seta o diretório do arquivo de LOG.
DIR_LOG="$DIR_SCRIPT/logs"
# O nome do arquivo de log será nome do arquivo .conf concatenado com YYYY-MM.log
LOG="$DIR_LOG/$CONFIG_NAME.$(date +%Y-%m).log"
# Coloca o path do arquivo .list como sendo o path do script, obrigando o usuário a salvar o arquivo
# na pasta do script
LISTA_BACKUP="$DIR_SCRIPT/$LISTA_BACKUP"
# Coloca o path do arquivo .excluded.list como sendo o path do script, obrigando o usuário a salvar o arquivo
# na pasta do script
NAO_FAZER_BACKUP="$DIR_SCRIPT/$NAO_FAZER_BACKUP"
# Seta o ponto de montagem do HD
HD="/mnt/$LABEL_HD"
# Coloca path da pasta onde será armazenado o backup a raíz do HD USB
LOCAL_BACKUP="$HD/$CONFIG_NAME"
# Seta o nome e local do arquivo de controle incremental. Sera nome do .conf concatenado
# com a extensão .inc armazenado na mesma pasta dos arquivos de backup no HD externo
CONTROLE_INCREMENTAL="$LOCAL_BACKUP/$CONFIG_NAME.inc"
# Seta o prefixo e path que será concatenado com os arquivos .full.tar.gz e inc.tar.gz
PREFIXO_ARQUIVO="$LOCAL_BACKUP/$(date +%Y-%m-%d_%A)"
# Nome do servidor
NOME_SERVIDOR=$(hostname)
# Ano atual com 4 dígitos
ANO=$(date +%Y)
# Mês atual com 2 dígitos
MES=$(date +%m)

# ======================================================================
# Função que escreve uma entrada no arquivo de log dentro da pasta logs
# no formato yyyy-mm-dd hh:mm:ss | texto do log
# ToLog "Mensagem que será armazenada no log"
# ======================================================================
ToLog() {
echo "$(date +%F' '%T) | $1" >> $LOG

}
# ======================================================================
# ======================================================================


# ======================================================================
# Função que verifica se todos os arquivos e diretórios essenciais para
# o funcionamento do script existem
# ======================================================================
CheckInicial() {
if [ -d $DIR_SCRIPT ] && [ -d $DIR_LOG ] && [ -e $LISTA_BACKUP ] && [ -e $NAO_FAZER_BACKUP ]

	then
	ToLog "Encontrados os arquivos e diretórios essenciais para o script" 
	return 0

	else
	MSG="ERRO! Algum(ns) arquivo(s) e diretório(s) não foi(ram) encontrado(s): $DIR_SCRIPT $DIR_LOG $LISTA_BACKUP $NAO_FAZER_BACKUP. O Backup foi abortado"
	ToLog "$MSG" 
	EnviarEmail "ERRO: Backup abortado no servidor $NOME_SERVIDOR" "$MSG" 
	exit

fi
}

# ======================================================================
# Função que checa se um diretório permite escrita
# ======================================================================
CheckWrite() {
touch "$1/write.test" 2>> $LOG
if [ $? -eq 0 ] 
    
			then
    	rm -rf "$1/write.test" 2>> $LOG
			return 0 
    	
			else
			return 1
fi
}

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  EnviarEmail
#   DESCRIPTION:  Envia email
#    PARAMETERS:  $1 = Assunto e $2 = Corpo do email
#       RETURNS:  
#-------------------------------------------------------------------------------
EnviarEmail() {
ASSUNTO=$1
CORPO=$2

echo "$CORPO" | mail -s "$ASSUNTO" "$DESTINATARIO"
ToLog "Email enviado para: $DESTINATARIO assunto: $ASSUNTO" 
}



#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  HDPlugado
#   DESCRIPTION:  Checa a existência do link para HD na pasta /dev/disk/by-label
#    PARAMETERS:  str Label
#       RETURNS:  
#-------------------------------------------------------------------------------
HDPlugado() {
	# Checa se existe um link simbólico com o label do HD no diretório /dev/disk/by-label/
if [ -L "$PATH_HD" ]

	then
	ToLog "$LABEL_HD plugado! Encontrado o link em $PATH_HD"

	else
	MSG="O HD $LABEL_HD não está plugado em uma porta USB"
	ToLog "$MSG" 
	EnviarEmail "ERRO: Backup abortado no servidor $NOME_SERVIDOR" "$MSG" 
	exit
fi	
}


#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  HDMontado
#   DESCRIPTION:  Checa se o HD está montado
#    PARAMETERS:  
#       RETURNS:  0=HD montado 1=HD não montado
#-------------------------------------------------------------------------------
HDMontado(){
 # busca pelo ponto de montagem na saída do comando mount	
 # a opção -q (quiet) do grep faz com que o comando não emita saída
mount | grep -q "$HD"
if [ $? -eq 0 ] 
			
			then
    	ToLog "Foi encontrado o HD $LABEL_HD montado em $HD" 
			return 0 			

			else
    	ToLog "O HD $LABEL_HD não está montado" 
			return 1
fi
}
# ======================================================================
# ======================================================================

#---  FUNCTION  ----------------------------------------------------------------
#          NAME:  Monta
#   DESCRIPTION:  Monta o HD externo
#    PARAMETERS:  
#       RETURNS:  
#-------------------------------------------------------------------------------
Monta() {
mount -t $FSHD $PATH_HD $HD 2>> $LOG
if [ $? -eq 0 ]
	
	then
	# Se a montagem ocorrer com sucesso exibe a mensagem no log
	ToLog "HD $LABEL_HD montado com sucesso em $HD!!!"
	return 0

	else
	#Caso contrário aborta o backup e manda email pro admin
	MSG="Falha ao tentar montar o HD $LABEL_HD em $HD. O Backup foi abortado"
	ToLog "$MSG"
	EnviarEmail "ERRO: Backup abortado no Servidor $NOME_SERVIDOR"
	exit
fi
}

Desmonta() {
	#---  FUNCTION  ----------------------------------------------------------------
	#          NAME:  Desmonta
	#   DESCRIPTION:  Monta o HD externo, criando ponto de montagem se necessário
	#    PARAMETERS:  
	#       RETURNS:  
	#-------------------------------------------------------------------------------
#se tiver montado desmonta
HDMontado
if [ $? -eq 0 ]
	
		then
		umount $HD
				if [ $? -eq 0  ]
			
				then
				ToLog "O HD $LABEL_HD foi desmontado" 
				rmdir $HD 2>> $LOG
						
							if [ $? -eq 0 ]
							then
							ToLog "Removido o diretório $HD"
						
							else
							ToLog ">>> ATENÇÃO: Não foi possível remover o diretório $HD"
							fi
			
				else
				ToLog ">>> ATENÇÃO: Não foi possível desmontar o HD $LABEL_HD montado em $HD"
				fi 

		else
		ToLog "O HD $LABEL_HD já está desmontado" 
fi
}



	#---  FUNCTION  ----------------------------------------------------------------
	#          NAME:  EmailLog
	#   DESCRIPTION:  Envia email com o resumo do log
	#    PARAMETERS:  
	#       RETURNS:  
	#-------------------------------------------------------------------------------
EmailLog() {
ToLog "Removendo logs antigos de emails enviados"
rm -f $DIR_LOG/$CONFIG_NAME.mail* >> $LOG

LOG_MAIL="$DIR_LOG/$CONFIG_NAME.mail.$(date +%F_%H_%M_%S).log"

echo "Backup realizado em $(date +%F' '%T)" >> $LOG_MAIL

echo "= = = = = = = = = = = = = = = = = = = = = = = = =" >> $LOG_MAIL
echo "Status das partições do servidor $NOME_SERVIDOR" >> $LOG_MAIL
df -h >> $LOG_MAIL
echo " "

echo "= = = = = = = = = = = = = = = = = = = = = = = = = =" >> $LOG_MAIL
echo "Conteudo do diretorio $LOCAL_BACKUP" >> $LOG_MAIL
ls -RlhA $LOCAL_BACKUP >> $LOG_MAIL
echo " "

# Envia email com conteúdo do arquivo de log
ASSUNTO="Backup realizado no servidor $NOME_SERVIDOR em $(date +%F' '%T)"
cat $LOG_MAIL | mail  -s "$ASSUNTO" $DESTINATARIO

# Adiciona a ação de email enviado ao log
ToLog "Email enviado para: $DESTINATARIO assunto: $ASSUNTO" 
}

# ======================================================================
# ======================================================================


# ======================================================================
# Função que executa um backup full | Deve ser ativada caso não exista
# backup FULL feito no mês
# ======================================================================
BackupFull(){
# Remove o arquivo de controle incremental que será criado automaticamente
# durante o backup full
rm -fv $CONTROLE_INCREMENTAL >> $LOG
ToLog "Removido arquivo $CONTROLE_INCREMENTAL" 

# Remove todos os arquivos incrementais
rm -fv $LOCAL_BACKUP/*$CONFIG_NAME.inc* >> $LOG
ToLog "Removendo os arquivos incrementais abaixo do diretório $LOCAL_BACKUP" 

# Gera um backup FULL
NOME_ARQUIVO="$PREFIXO_ARQUIVO.$CONFIG_NAME.full.tar.gz"
tar -czp --ignore-failed-read --exclude-from=$NAO_FAZER_BACKUP -g $CONTROLE_INCREMENTAL -f $NOME_ARQUIVO -T $LISTA_BACKUP
ToLog "Criado arquivo de Backup $NOME_ARQUIVO" 

# Cria arquivo .log e envia seu conteúdo para o email especificado
EmailLog

# Desmonta o HD
Desmonta

}
# ======================================================================
# ======================================================================


# ======================================================================
# Executa o backup incremental
# ======================================================================
BackupIncremental() {

# Gera um backup Incremental
NOME_ARQUIVO="$PREFIXO_ARQUIVO.$CONFIG_NAME.inc.tar.gz"
tar -czp --ignore-failed-read --exclude-from=$NAO_FAZER_BACKUP -g $CONTROLE_INCREMENTAL -f $NOME_ARQUIVO -T $LISTA_BACKUP
ToLog "Criado arquivo de Backup Incremental $NOME_ARQUIVO" 

# Cria arquivo .log e envia seu conteúdo para o email especificado
EmailLog

# Desmonta o HD
Desmonta

}

# ======================================================================
# ======================================================================

         
# ======================================================================
# Função que apaga os arquivos .OLD mas antigos de acordo com a 
# configuração
# ======================================================================
ApagaOld() {

if [ $(ls $LOCAL_BACKUP/ | egrep -c ^[0-9]{4}-[0-9]{2}.*$CONFIG_NAME.full.tar.gz.OLD$) -eq 0 ]
		then
			ToLog "Não há arquivos AAAA-MM.$CONFIG_NAME.full.tar.gz.OLD em $LOCAL_BACKUP"
			return
		else
		# array com todos os arquivos OLD encontrados no diretório
		ARQUIVOS_OLD=($(ls $LOCAL_BACKUP/ | egrep ^[0-9]{4}-[0-9]{2}.*$CONFIG_NAME.full.tar.gz.OLD$))
fi

for OLD in ${ARQUIVOS_OLD[@]}
do
ANO_OLD=$(echo $OLD | cut -c 1-4)
MES_OLD=$(echo $OLD | cut -c 6-7)
# Diferença do ano da data atual em relação a data referência do arquivo
# multiplicado por 12 para permitir o cálculo da diferença de meses
DIFF_ANO=$((($ANO - $ANO_OLD)*12))
# Diferença entre os meses das datas
DIFF_MES=$(expr $MES - $MES_OLD)
# Diferença de meses entre a data atual e a data de referencia do arquivo
DIFF=$(($DIFF_ANO + $DIFF_MES))

	if [ $DIFF -gt $N_OLD ]
		then
	ToLog "Removido o arquivo $OLD pois é muito antigo de acordo com as configurações" 
        rm -f $LOCAL_BACKUP/$OLD >> $LOG
	fi
done
}
# ======================================================================
# ======================================================================


# ======================================================================
# Arquivamento dos logs
# 
# ======================================================================
ArquivaLogs() {

if [ $(ls $DIR_LOG/ | egrep -c ^$CONFIG_NAME.[0-9]{4}-[0-9]{2}.log$) -eq 0 ]
		then
			ToLog "Não há arquivos .log indicados para arquivamento"
			return
		else
			# array com todos os arquivos FULL encontrados no diretório
			ARQUIVOS_LOG=($(ls $DIR_LOG/ | egrep ^$CONFIG_NAME.[0-9]{4}-[0-9]{2}.log$))
fi

# Para cada arquivo .log dentro da array
for A_LOG in ${ARQUIVOS_LOG[@]}
do
DATA_LOG=$(echo $A_LOG | cut -f2 -d.)
MES_LOG=$(echo $DATA_LOG | cut -c 6-7)
	if [ $MES_LOG -ne $MES ]
		then
			tar -czf $DIR_LOG/$A_LOG.tar.gz $DIR_LOG/$A_LOG
			rm -f $DIR_LOG/$A_LOG
			ToLog "Arquivo $A_LOG compactado"
	fi
done
}

# ======================================================================
# Função que busca por todos os arquivos full.tar.gz e renomeia
# com a data do mes passado e final full.tar.gz.OLD
# ======================================================================
GeraOld() {


if [ $(ls $LOCAL_BACKUP/ | egrep -c ^[0-9]{4}-[0-9]{2}-[0-9]{2}.*$CONFIG_NAME.full.tar.gz$) -eq 0 ]
		then
			ToLog "Não há arquivos indicados para arquivamento (OLD)"
			return
		else
			# array com todos os arquivos FULL encontrados no diretório
			ARQUIVOS_FULL=($(ls $LOCAL_BACKUP/ | egrep ^[0-9]{4}-[0-9]{2}-[0-9]{2}.*$CONFIG_NAME.full.tar.gz$))
fi


# Para cada arquivo FULL dentro da array
for FULL in ${ARQUIVOS_FULL[@]}
do
# Pega dez dígitos a partir do primeiro dígito do nome do arquivo
# ou seja, a data. ex.: 2012-01-12
DATA_FULL=$(echo $FULL | cut -c 1-10)
# Mes passado em relação a data no nome do arquivo no formato YYYY-MM
MES_PASSADO=$(date --date "$DATA_FULL 1 months ago" +%Y-%m)

        mv $LOCAL_BACKUP/$FULL $LOCAL_BACKUP/$MES_PASSADO.$CONFIG_NAME.full.tar.gz.OLD 2>> $LOG
	ToLog "Criado arquivo Morto $MES_PASSADO.$CONFIG_NAME.full.tar.gz.OLD" 
	
done
	MSG="Arquivo(s) morto(s) existente(s): $(ls $LOCAL_BACKUP | grep .*tar.gz.OLD)"
	EnviarEmail "Criado arquivo Morto no Servidor $NOME_SERVIDOR" "$MSG"

}


# **********************************************************************
# INICIO DO SCRIPT DE BACKUP
# **********************************************************************

# Abre uma entrada no log
ToLog "########## ROTINA DE BACKUP INICIADA ##########"

# Checa se os arquivos e diretórios essenciais para script existem
CheckInicial

# Checa se o HD está plugado se não tiver manda email
HDPlugado

# Checa se o HD está montado, se não tiver tenta montá-lo
HDMontado
if [ ! $? -eq 0 ]
	then
		# O HD não está montado
				# Testa se o ponto de montagem existe
				if [ -d "$HD" ]
					then
						# Ponto de montagem existe
						ToLog "Encontrado o ponto de montagem $HD"
						# Tenta montar o HD
						Monta
				else
						# Ponto de montagem não encontrado
						ToLog "O ponto de montagem $HD não existe, tentaremos criá-lo"			
						mkdir -p $HD 2>> $LOG
							if [ $? -eq 0 ]
								then 
									# Diretório do ponto de montagem criado	
									ToLog "Criado diretório $HD que servirá como ponto de montagem para o HD externo"
									# Tenta montar o HD
									Monta
								else
									MSG="ERRO: Não foi possível criar o ponto de montagem em $HD. Backup abortado"
									ToLog "$MSG"
									EnviarEmail "ERRO: Backup abortado no servidor $NOME_SERVIDOR" "$MSG"
									exit
							fi		
				fi	
fi
# Compacta os arquivos .logs que não são do mês atual
ArquivaLogs

# Verifica se o diretório que receberá os backups existe, se existir
# tenta criar
if [ ! -d $LOCAL_BACKUP ]
	then
		ToLog "Não foi encontrado $LOCAL_BACKUP em $HD. Tentarei criá-lo para você"
		mkdir $LOCAL_BACKUP 2>> $LOG
			if [ $? -eq 0 ]
				then 
					ToLog "Foi criado o diretório $LOCAL_BACKUP em $HD"
				else
					MSG="Não foi possível criar o diretório $LOCAL_BACKUP em $HD. O backup será abortado"
					ToLog "$MSG"
					EnviarEmail "ERRO: Backup abortado no Servidor $NOME_SERVIDOR" "$MSG"
					exit

			fi
fi
# Verifica se é possível escrever no diretório onde será feito o backup
CheckWrite $LOCAL_BACKUP
if [ $? -eq 0 ]
	then
		ToLog "O teste de escrita em $LOCAL_BACKUP foi executado com sucesso." 
	else
		ToLog "Backup Abortado. O teste de escrita em $LOCAL_BACKUP falhou." 
			MSG="Falha ao tentar escrever em $LOCAL_BACKUP. O Backup foi abortado"
			EnviarEmail "ERRO: Backup abortado no Servidor $NOME_SERVIDOR" "$MSG"
			exit
fi

# Procura por um backup full com uma data dentro do mes
# se não existir faz um backup full caso contrário faz
# backup incremental
MES_ATUAL=$(date +%m)

if [ $(ls $LOCAL_BACKUP/ | egrep -c ^[0-9]{4}-$MES_ATUAL-[0-9]{2}.*$CONFIG_NAME.full.tar.gz$) -eq 0 ]
	# Se não existir FULL do mês atual
        then
		# Antes de executar o FULL do mes atual vamos renomear todos os full.tar.gz existentes
		# para arquivos mes_passado.full.tar.gz.OLD	
		GeraOld
		
		# Apaga todos os arquivos OLD que são muito antigos, de acordo com a configuração
		ApagaOld
			
		ToLog "Iniciado Backup FULL" 
		BackupFull 
			if [ $? -eq 0 ]
				then
		ToLog "Finalizado Backup FULL" 
				else
				ToLog "O Backup FULL não foi realizado" 
			fi
	else
		# Se já existe backup full do mês  vamos execurar um incremental
		ToLog "Iniciado Backup Incremental" 
		BackupIncremental
			if [ $? -eq 0 ]
				then
		ToLog "Finalizado Backup Incremental" 
				else
		ToLog "O Backup Incremental não foi realizado" 
			fi
fi
