# Adicionar um modelo

[English](../add-a-model.md) · **Português (Brasil)**

Qualquer IA que mostre o uso em algum lugar que você consiga ler no seu Mac pode ir para o notch. O AIControlNotch roda um script curto seu de tempos em tempos, lê o JSON da saída padrão e desenha ao lado do Claude e do Codex, com o mesmo ponto de ritmo e o mesmo aviso a cada 10 pontos.

**O jeito fácil:** peça para a sua IA. Cole isto no Claude Code, no Codex ou em qualquer assistente que rode comandos no seu Mac (troque o nome da ferramenta):

```text
Conecte o Gemini ao AIControlNotch. Siga o passo 6 de https://github.com/noha-agencia/AIControlNotch/blob/main/docs/install-with-ai.md, fale comigo em português e me pergunte antes de mudar qualquer coisa.
```

Ela procura uma fonte segura dos números, escreve e testa o script com você e adiciona ao app. O resto desta página é a referência, para fazer à mão.

## De onde os números podem vir

Use só fontes que não pedem segredo novo:

- um arquivo que a própria ferramenta do modelo já grava no seu Mac;
- um comando que a própria ferramenta do modelo já traz.

Não raspe sites, não leia cookies do navegador, não peça senha e não guarde token. Se os números só existirem nos servidores do fornecedor, use um comando da própria ferramenta dele que os busque. Um script nunca deve ler, copiar nem enviar o token dessa ferramenta por conta própria.

## Início rápido

1. Copie o modelo para a pasta do app e torne-o executável:

   ```bash
   mkdir -p ~/Library/Application\ Support/AIControlNotch/scripts
   chmod 700 ~/Library/Application\ Support/AIControlNotch/scripts
   cp examples/providers/template.sh ~/Library/Application\ Support/AIControlNotch/scripts/exemplo.sh
   chmod 700 ~/Library/Application\ Support/AIControlNotch/scripts/exemplo.sh
   ```

2. Confira que ele imprime um JSON válido:

   ```bash
   ~/Library/Application\ Support/AIControlNotch/scripts/exemplo.sh | python3 -m json.tool
   ```

3. Clique com o botão direito no notch, escolha **Configurar modelos…** e adicione o modelo (veja abaixo). O modelo imprime números fixos de exemplo: troque o passo 1 dele pela sua fonte real.

4. Salve o arquivo. A mudança entra na próxima atualização; **Recarregar modelos** relê na hora. Se o arquivo tiver um erro, o menu diz qual e onde, e as últimas configurações válidas continuam valendo.

## 1. Configure

**Configurar modelos…** cria e abre `~/Library/Application Support/AIControlNotch/providers.json`:

```json
{
  "pinned": ["claude", "codex"],
  "disabled": [],
  "providers": [
    {
      "id": "meumodelo",
      "name": "Meu Modelo",
      "color": "#5B8CFF",
      "command": ["~/Library/Application Support/AIControlNotch/scripts/meumodelo.sh"],
      "intervalSeconds": 300,
      "timeoutSeconds": 15
    }
  ]
}
```

| Campo | Significado |
|---|---|
| `pinned` | Modelos mostrados no notch em repouso, até dois ids. Um modelo desabilitado deixa de ser fixado; se nenhum sobrar, entram os primeiros habilitados. |
| `disabled` | Ids para esconder. Pelo menos um modelo fica habilitado, e no máximo 6. |
| `id` | Slug único: letras minúsculas, dígitos e `-`, até 32 caracteres, sem começar com `-`. Diferente de `claude` e `codex`. |
| `name` | Nome mostrado no painel e nos avisos, de 1 a 24 caracteres visíveis. |
| `color` | Cor hexadecimal, `#RRGGBB`. Modelos de terceiros ganham um monograma nessa cor. |
| `command` | O script, como lista argv. Use o caminho completo; `~/` no começo de qualquer item é a sua pasta pessoal, mas `$HOME` e outras variáveis não são expandidas, porque não há shell. |
| `intervalSeconds` | Segundos entre execuções: 300 por padrão, de 60 a 86400. |
| `timeoutSeconds` | Segundos até o script ser encerrado: 15 por padrão, no máximo 60. |

O [`examples/providers/providers.example.json`](../../examples/providers/providers.example.json) é um arquivo pronto com um modelo de exemplo.

## 2. Imprima JSON

O seu script escreve isto na saída padrão (stdout):

```json
{
  "version": 1,
  "plan": "Pro",
  "windows": [
    {"label": "5h", "durationMinutes": 300, "usedPercent": 38.5, "resetsAt": "2026-10-05T18:00:00Z"},
    {"label": "Semana", "durationMinutes": 10080, "usedPercent": 12, "resetsAt": "2026-10-09T09:00:00Z"}
  ]
}
```

| Campo | Significado |
|---|---|
| `version` | Sempre `1`. |
| `plan` | Texto opcional ao lado do nome do modelo, até 24 caracteres visíveis. |
| `windows` | Os limites do modelo, até 4, um por duração (veja abaixo). |
| `windows[].label` | Rótulo opcional da linha, até 24 caracteres visíveis. |
| `windows[].durationMinutes` | Duração da janela, um número inteiro de 1 a 525600 (300 são 5 horas, 10080 é uma semana). |
| `windows[].usedPercent` | Quanto do limite já foi usado, de 0 a 1000 (100 significa limite atingido). |
| `windows[].resetsAt` | Horário opcional em ISO 8601 em que a janela renova. Deixe de fora quando a janela ainda não começou. |

O ponto de ritmo precisa de `resetsAt` e `durationMinutes` para dizer se o limite vai durar até renovar.

As janelas se distinguem pela classe de duração: cerca de 5 horas, cerca de uma semana, um número de minutos abaixo de um dia ou um número de dias. Avisos e linhas do painel usam essa classe, então duas janelas de duração parecida (por exemplo, 10080 e 10000 minutos) são recusadas, e o erro cita as duas.

O [`examples/providers/template.sh`](../../examples/providers/template.sh) é um script bash comentado que imprime um documento válido.

## Como os scripts rodam

- **Sem shell.** `command` é uma lista argv, então pipes e `$VAR` não são expandidos. Coloque isso dentro do script. Só um `~/` no começo é expandido.
- **Ambiente mínimo.** Só `HOME`, `LANG` e `PATH` (`/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin`). O diretório de trabalho é a sua pasta pessoal.
- **Tempo e tamanho.** Timeout de 15 s por padrão, 60 s no máximo; depois o script e o que ele tiver iniciado são encerrados. No máximo 64 KB na saída padrão. Um script roda no máximo uma vez a cada `intervalSeconds` (uma vez por minuto com **Atualizar agora**).
- **Erros ficam visíveis.** Código de saída diferente de zero, JSON inválido ou valor fora do intervalo vira um problema no painel, com o nome do modelo e o motivo. Nunca derruba o app e nunca mostra um número inventado. O que o script escrever em stderr vai para o log, truncado, com o que parecer token ou senha escondido.
- **O `providers.json` é código: ele decide quais programas o app executa.** Ele precisa ser seu e não pode ter permissão de escrita para outros usuários (`chmod 600` nele), senão é ignorado.
- **Os scripts também.** O programa, qualquer arquivo citado nos argumentos e as pastas onde eles estão precisam ser seus (ou do sistema) e não podem ter permissão de escrita para outros (`chmod go-w`). Pastas que só administradores alteram, como a `bin` do Homebrew, são aceitas. Senão, o painel diz "outros usuários podem alterar os arquivos dele" e o script não roda.
- **Seu usuário, sua confiança.** Um script roda com as suas permissões. Só adicione scripts que você leu e em que confia.

O painel ao passar o mouse mostra todos os modelos habilitados, os fixados primeiro, até 6. Quando passam de 12 linhas, os limites menos usados dos modelos com mais janelas ficam fora do painel (todo modelo mantém pelo menos um). Os avisos a cada 10 pontos valem para todos.

## Compartilhar um script

O repositório só traz o modelo, porque todo exemplo precisa ser verificado: ele tem que ler arquivos ou comandos locais da própria ferramenta do modelo, não pedir senha nem token e nunca raspar um site. Se você escreveu um script que cumpre isso, abra uma [issue de novo modelo](https://github.com/noha-agencia/AIControlNotch/issues/new/choose) ou um pull request. Veja o [CONTRIBUTING.md](../../CONTRIBUTING.md).
