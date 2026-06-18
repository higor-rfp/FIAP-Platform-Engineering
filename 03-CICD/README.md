# 03 — CI/CD com GitLab

Módulo prático sobre **integração e entrega contínua de infraestrutura** com **GitLab CI/CD** rodando no seu próprio **GitLab Runner** (o mesmo que você provisionou com Ansible no módulo 02). A ideia central: transformar o `terraform plan` / `terraform apply` que você rodava na mão em um **pipeline automático**, acionado a cada `push` na branch `master`, com um **gate de segurança** que barra configuração insegura **antes** dela chegar na nuvem.

São **2 demos sequenciais + 1 exercício**, todos sobre o repositório `primeiro-projeto` no GitLab e o runner registrado no módulo anterior.

## Mês 3 do arco da Vortex Mobility

> **Segunda-feira, 10h. Três meses depois da sua entrada na Vortex Mobility.**
> A infraestrutura já é toda código (módulo 01) e o provisionamento de servidores já é repetível com Ansible (módulo 02). **Diego Tavares**, seu mentor SRE, te chama numa call rápida:
>
> > *— "Temos o runner de pé. Mas ainda tem gente rodando `terraform apply` do laptop. Isso me tira o sono: ninguém revisa o `plan`, ninguém valida se a config é segura, e quando dá ruim a gente descobre na fatura da AWS. Quero que **todo push na master** rode `plan` e `apply` sozinho — e que tenha um **gate de segurança** que **barre configuração insegura ANTES** de chegar na nuvem."*

Este é o terceiro mês do arco. A pergunta-âncora do repositório inteiro — *"quanto tempo a Vortex leva para recriar toda a sua infraestrutura do zero, de forma confiável e auditável?"* — chega à sua resposta final aqui: **um push, automatizado e validado**.

## Os 3 itens deste módulo

| # | Item | O que você faz | Tempo estimado |
|---|------|----------------|----------------|
| **03.1** | **[Primeiro pipeline](01-Primeiro-pipeline/README.md)** | Cria o `.gitlab-ci.yml` com dois stages — `plan` (CI) e `apply` (CD) — e vê o pipeline rodar sozinho a cada push na `master`. | 30-45 min |
| **03.2** | **[Validando e gerando relatórios](02-Validando-e-gerando-relatorios/README.md)** | Adiciona um stage `validate` com `terraform validate` + **Checkov** (gate de segurança), gerando relatório JUnit visível na aba **Tests** do GitLab. | 30-45 min |
| **03.3** | **[Exercício](03-Exercicio/README.md)** | Consolida tudo: pega o código da demo Count, cria um novo repositório, configura estado remoto e monta um pipeline de **3 stages** end-to-end por conta própria. | 60-90 min |

> [!TIP]
> Faça na ordem: 03.1 → 03.2 → 03.3. A demo 03.2 evolui o mesmo `.gitlab-ci.yml` da 03.1, e o exercício 03.3 só faz sentido depois de você ter visto os 3 stages funcionando.

## Pré-requisitos do módulo

> [!WARNING]
> Este módulo **depende dos módulos 01 e 02**. Antes de começar **qualquer** item daqui:
>
> - [ ] **Módulo 01 concluído** — você sabe rodar `terraform init/plan/apply` e configurar estado remoto no S3.
> - [ ] **Módulo 02 concluído** — você tem um **GitLab Runner registrado** com a tag `shell`, e o repositório **`primeiro-projeto`** existe na sua conta do GitLab com o código Terraform versionado.
> - [ ] **Chave SSH do GitLab** configurada no Codespaces (`/home/vscode/.ssh/gitlab`) — criada no módulo 02.
> - [ ] **Credenciais AWS do Academy atualizadas** no Codespaces.
>
> **Valide rapidamente** (no terminal do Codespaces):
>
> ```bash
> aws sts get-caller-identity
> ```
>
> E confira, no GitLab, em **Settings → CI/CD → Runners**, que existe um runner online com a tag `shell`. Se não tiver, volte ao [módulo 02](../02-Ansible/01-provisionando-gitlab-runner/README.md).

## Storytelling: a empresa fictícia Vortex Mobility

Para amarrar o repositório inteiro, seguimos a narrativa da **Vortex Mobility** — startup brasileira de micromobilidade (e-scooters e e-bikes) escalando de 3 para 30 cidades:

- **Helena Marques** (Head de Engenharia de Plataforma) — abriu os módulos 01 e 02 com demandas de negócio.
- **Diego Tavares** (SRE sênior, seu mentor) — abre **este módulo** e aparece nos checkpoints cobrando automação e segurança.
- **Você** (Platform Engineer recém-contratado) — implementa o pipeline.

Cada demo vira **uma resposta concreta** ao pedido do Diego: primeiro o pipeline roda sozinho (03.1), depois ele vira **confiável** com um gate de validação (03.2), e por fim você prova que sabe montar tudo do zero (03.3).

## Decisões pedagógicas

1. **Por que GitLab CI/CD e não GitHub Actions?** Você já registrou um GitLab Runner próprio no módulo 02. Manter a continuidade (mesmo runner, mesmo `primeiro-projeto`) deixa o arco coeso e mostra o runner self-hosted em uso real.
2. **Por que `tags: shell`?** O runner do módulo 02 foi registrado com o executor `shell`, rodando direto no servidor EC2 (com Terraform, AWS CLI e Checkov já instalados via Ansible). É isso que faz cada job encontrar `terraform` no PATH.
3. **Por que Checkov como gate?** Checkov é um scanner de IaC amplamente adotado no mercado. Ele transforma "config insegura" em algo objetivo e automatizável — exatamente o que o Diego pediu para "barrar antes de chegar na nuvem".

## Custo do módulo

O pipeline em si não cria infraestrutura nova além da que o Terraform do `primeiro-projeto` já provisiona (uma fila SQS, na demo 03.1) e dos recursos da demo Count no exercício (instâncias EC2 + ELB).

> [!CAUTION]
> O exercício **03.3 cria EC2 + ELB**, que são **pagos**. Ao terminar, rode `terraform destroy -auto-approve` (ou adicione um job de destroy ao pipeline, conforme instruído no lab). Esquecer 2 EC2 `t3.micro` + 1 ELB ligados por 1 dia consome parte relevante do orçamento do Learner Lab.

## Próximo passo

Após concluir os 3 itens deste módulo, você terá o fio condutor do repositório fechado. Prossiga para:

**[Trabalho Final](../Trabalho-final/README.md)** — onde você junta Terraform, Ansible e CI/CD para entregar a infraestrutura da Vortex de ponta a ponta.
