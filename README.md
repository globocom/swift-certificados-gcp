# Swift-Certificados-GCP

Projeto criado para renovar certificados associados ao balanceador utilizando o Cloud Build.

## Requisitos
- Possuir uma conta no GCP.
- Ativar a API Cloud Build.
- Ativar a API Cloud Scheduler.

## Passo a passo para criar a trigger no Cloud Build

- Conceder permissões de função IAM do cloudbuild à conta de serviço utilizada, as permissões são:
    - Editor do Cloud Build.
    - Gravador de registros.
    - Gravador da métrica de monitoramento.
    - Usuário da conta de serviço.
    - Administrador do balanceador de carga do Compute.
    - Proprietário do Gerenciador de certificados.
    - Visualizador do Compute.

- Configurar uma trigger manual no Cloud Build.
    - No console, em ```Cloud Build > Build Triggers``` pode-se criar uma nova trigger. 

    - É necessário apontar a trigger para esse repositório.

    - Definir as variáveis de ambiente que estão no script do ```cloudbuild.yaml```, as variáveis são:
        - _LOAD_BALANCER: Nome do proxy HTTPS usado ​​pelo balanceador.
        - _PROJECT: Nome do projeto que contém os certificados.
        - _REGION:Região que está o balanceador.
    
    - Associar uma conta de serviço a trigger que contenha as permissões acima.

    - Em seguida, é importante localizar a linha que contém o nome da trigger e escolher a opção: ```Executar programação```, pois com essa opção pode-se selecionar a frequência de execução da trigger com o Cloud Scheduler.
        - As configurações de job do Cloud Scheduler são as seguintes:
            - Nome: um nome do job do Cloud Scheduler.
            - Descrição (opcional): uma descrição do job do Cloud Scheduler.
            - Frequência: selecione a frequência com que a trigger será executada.

## Monitoração

Pode-se criar uma monitoração para a trigger no Cloud Build, passo a passo dela está abaixo:

- Ir na aba ```Registros > Métricas baseadas em registros```, e clicar na opção ```Criar nova métrica```.
    - Selecionar ```Counter``` como o Tipo de métrica.
    - No campo ```Unidades```, colocar ```1```.
    - Preencher o filtro com: 
        ```
        resource.type="build" 
        severity=ERROR 
        OR não foi criado 
        ```
    - Se no mesmo projeto tiver mais de uma monitoração, preencher o filtro com o ID da build:
        ```
        resource.type="build" 
        severity=ERROR 
        OR não foi criado 
        AND resource.labels.build_trigger_id=<id-build>
        ```
    - Por fim, conferir e criar a métrica.

Com a métrica criada, é necessário criar um Alerta para ela:
- Ir na aba ```Monitoramento > Alertas```.
- Clicar na opção ```Criar Política``` e selecionar a métrica criada.