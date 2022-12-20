#!/bin/bash

#Install jq
apt update && apt install jq -y 

#Name of certificates
load_balancer_certificates=($(gcloud compute target-https-proxies describe ${load_balancer} --region us-east1 --format=json | jq -r '.sslCertificates[]'))

for lbc in ${load_balancer_certificates[@]}; do

    #Select certificate expiration date
    ssl_date=$(gcloud compute ssl-certificates describe ${lbc} --region=us-east1 --format=json | jq .expireTime)
    ssl_date=${ssl_date:1:10}
    ssl_date=$(echo $ssl_date | tr -d "-")

    #Current date more five days
    date=$(date --date="+5 days" +"%F")
    date=$(echo $date | tr -d "-")

    #Curret date
    date_today=$(date "+%F:%H:%M")
    date_today=$(echo $date_today | tr -d "-" | tr -d ":")

    if [[ $ssl_date -le $date ]]; then

        echo "Renovando certificado ${lbc}"

        #Get name of certificate
        certificate=$(gcloud compute ssl-certificates describe ${lbc} --region=us-east1 --format=json | jq -r .name)

        #Get FQDN
        host_certificate=$(gcloud compute ssl-certificates describe ${lbc} --region=us-east1 --format=json | jq .subjectAlternativeNames | xargs | awk '{print $2}')
        file_name=$(gcloud compute ssl-certificates describe ${lbc} --region=us-east1 --format=json | jq .subjectAlternativeNames | xargs | awk '{print $2}' | sed 's/\./-/g')

        echo "Cria certificado com o nome ${file_name}-${date_today}"
        #Obtém certificado do secret manager e salva em um arquivo
        gcloud secrets versions access latest --secret=${file_name}-crt --project ${project} > ${file_name}.crt
        gcloud secrets versions access latest --secret=${file_name}-key --project ${project} > ${file_name}.key

        gcloud compute ssl-certificates create ${file_name}-${date_today} --certificate=${file_name}.crt --private-key=${file_name}.key --region=us-east1
        
        #ID of certificate created
        certificate_id=$(gcloud compute ssl-certificates describe ${lbc} --region=us-east1 --format=json | jq -r .id)

        if [ ! -z "${certificate_id}" ]; then

            echo "Atualiza certificado no balanceador"
            #Get name of target
            target_proxy=$(gcloud compute target-https-proxies list --filter="SSL_CERTIFICATES:'${lbc}'" --format=json | jq -r '.[].name')
            #Get all certificates currently on the load-balancer less the will be delete
            list_certificate=$(gcloud compute target-https-proxies list --format=text --filter="SSL_CERTIFICATES:'${lbc}'" |grep sslCertificates |grep -v ${lbc} | awk -F "/" '{print $NF}')
            gcloud compute target-https-proxies update ${target_proxy} --ssl-certificates=${file_name}-${date_today},${list_certificate} --region=us-east1
            
            echo "Deleta certificado antigo"
            gcloud compute ssl-certificates delete ${certificate} --region=us-east1 --quiet

            load_balancer=$(gcloud compute target-https-proxies list --format=text --filter="SSL_CERTIFICATES:'${lbc}'" | grep urlMap | awk -F "/" '{print $NF}')
            echo "Certificados associados ao balanceador ${load_balancer}"
            certificate_lb=$(gcloud compute target-https-proxies describe ${target_proxy} --region=us-east1 --format=json | jq .sslCertificates)
            echo $certificate_lb

        else

            echo "Certificado ${file_name}-${date_today} não foi criado, verificar!"
            exit 1

        fi
    
    else
        
        echo "O certificado ${lbc} está válido!"

    fi
  
done