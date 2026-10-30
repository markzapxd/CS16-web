# Deploy portátil CS 1.6 Web

Derivação `linux/amd64` da imagem upstream fixada por digest no Dockerfile. Nenhum arquivo do deploy local existente é copiado para a imagem. O container de produção não precisa ser alterado para construir/testar esta versão.

## Iniciar

```sh
docker compose up -d
```

Sem configuração adicional, baixa a imagem publicada e inicia `de_dust2` em
http://127.0.0.1:8080. A pasta `custom-content/` é criada automaticamente.
HTTP escuta em `0.0.0.0:8080`, acessível pelas interfaces do servidor.
Para jogar de outra máquina, configure `ADVERTISED_IP` com o IP acessível do
servidor no Compose ou em um `.env`. `0.0.0.0` é endereço de escuta, não um
endereço anunciável para WebRTC. Libere as portas descritas abaixo.
Se o pacote GHCR estiver privado, o Docker precisa estar autenticado para baixá-lo.

Para Garten, coloque os arquivos em `custom-content/cstrike/` e altere o padrão
`MAP` no `docker-compose.yaml` para `garten_v05`. Também é possível sobrescrever
`CONTENT_DIR`, `MAP`, `CS16_IMAGE` e demais opções por `.env`, sem ser obrigatório.

## Conteúdo customizado

Prepare o conteúdo **antes** de iniciar, fora do repositório:

```text
/srv/cs16-content/
  cstrike/
    maps/garten_v05.bsp
    models/...                 # dependências reais do mapa
    sound/...
    sprites/...
    *.wad
  preload.json                 # opcional
```

O mesmo diretório `cstrike` é vinculado, somente leitura na origem, a `/xashds/cstrike` (servidor nativo) e `/xashds/public/cstrike` (HTTP). Arquivos upstream existentes são preservados, não substituídos; remova/recrie o container após mudar a estrutura de conteúdo. Não monte um diretório vazio por cima de todo `/xashds/cstrike` ou `/xashds/public`: isso esconderia os arquivos originais.

Sem `preload.json`, o cliente baixa `cstrike/maps/${MAP}.bsp`. Para mapas com dependências adicionais, enumere **todos** os arquivos necessários, inclusive o BSP, em um array JSON:

```json
["cstrike/maps/garten_v05.bsp", "cstrike/models/garten/exemplo.mdl", "cstrike/exemplo.wad"]
```

Os caminhos são relativos ao conteúdo público, começam com `cstrike/`, não admitem `..` nem caracteres fora de letras, números, `_`, `-`, `.`, `/`. O manifesto é lido sem cache em cada inicialização do cliente. Erros HTTP interrompem o carregamento em vez de iniciar sem os recursos. `MAP` controla tanto o mapa inicial nativo como o preload padrão; não implementa preload automático ao trocar de mapa durante a partida. `MAXPLAYERS` tem padrão 16. Argumentos adicionais do container são encaminhados ao engine.

## Rede

A inspeção do container atual e do código confirmou:

- HTTP/estáticos e sinalização WebSocket: **27016/TCP interno**. O compose publica em `0.0.0.0:8080` por padrão. Ajuste `HTTP_BIND`/`HTTP_PORT` ou use proxy reverso com suporte a WebSocket e HTTPS.
- `PORT=27018` é a porta **WebRTC**, não HTTP. Publicamos 27018 TCP e UDP, mantendo o mesmo número no host e container. Libere/encaminhe essas portas no firewall/NAT; um proxy HTTP sozinho não transporta esse tráfego.
- `IP` anuncia o endereço ICE aos navegadores. `ADVERTISED_IP` tem padrão local `127.0.0.1` no compose e deve ser alcançável pelos jogadores, não o IP bridge do Docker. O container existente usa `10.7.4.3`; isso é específico daquela rede, não um padrão portátil.
- Engine nativo: 27015/UDP interno, não publicado neste exemplo.

Não execute este compose com 27018 enquanto outro container já usa essa porta. Para validar em paralelo, use um container isolado sem publicar WebRTC. Acessibilidade pela internet, NAT, TLS e jogabilidade externa precisam de validação na rede de destino.

## Patches e reprodução

`patch.py` verifica SHA-256 do executável e do bundle original e exige contexto único para cada substituição. Uma alteração upstream aborta o build. Não usa o `main.js` minificado da máquina local como fonte.

- Engine: SHA-256 original `5414c5feb550e8748f4fb5681a1470e736bb67b77923d85ed949c761e385fa75`; offset `0x084d0843 - 0x08048000`, bytes `8b04248b7c` → `e91d000000`. Desvia da liberação de ponteiro interior associada ao double free. É um workaround binário específico desta versão, não uma correção geral de gerenciamento de memória.
- Cliente: extração sequencial do ZIP, evitando descompactações simultâneas; download direto sem leitura/gravação do ZIP gigante em IndexedDB; preload HTTP configurável. O ZIP continua sendo baixado e mantido em memória, portanto não elimina o consumo de memória do jogo. Cache HTTP do navegador continua aplicável.
- O digest da imagem de jogo está fixado. A imagem auxiliar `python:3.12-alpine` ainda usa tag: fixe também seu digest para reprodução integral da cadeia de ferramentas.

## Validação realizada

Build Docker local concluído; bundle resultante aprovado por `node --check`; configuração compose validada; container separado com `MAP=de_dust2` iniciou servidor para 16 jogadores e respondeu HTTP 200 em `/` e manifesto correto em `/deployment-preload.json`. O container de produção permaneceu em execução, sem reinício.

Não foi validada nesta entrega uma sessão completa em navegador, mapa Garten com todas as dependências, troca de mapas, nem conectividade WebRTC externa. Os logs do ambiente existente apontam modelos Garten ausentes: fornecer somente o BSP não resolve essas dependências. O patch nativo foi aplicado com hashes/bytes conferidos; isso não constitui teste exaustivo de estabilidade.

## Publicação e licenças

O workflow `.github/workflows/portable-cs16.yaml` constrói a raiz do repositório e publica em `ghcr.io/markzapxd/cs16-web-portable/portable-cs16` por execução manual ou tags `portable-cs16-v*`. O workflow não é executado no push normal: verifique os direitos de redistribuição da imagem base antes de acioná-lo.

**Não envie `gamefiles.zip`, `valve.zip`, arquivos comerciais do Counter-Strike/Half-Life ou recursos de mapas sem autorização ao GitHub/GHCR.** O `.dockerignore` limita o contexto aos scripts de deploy. A imagem base já contém dados do jogo: herdar essa imagem também pode redistribuí-los. A licença do código deste repositório não concede direitos sobre conteúdo Valve ou mapas de terceiros; verifique os direitos antes de publicar, inclusive imagens derivadas e pacotes públicos. Volumes externos não substituem essa análise jurídica.
