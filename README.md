# 🛒 Feira Fácil

**Feira Fácil** é um aplicativo mobile feito em Flutter para registrar, organizar e acompanhar as compras do mês da sua casa. Com ele você deixa de depender de papelzinho e memória e passa a ter o controle de quanto gasta, o que mais consome e como os preços mudam de uma feira para outra.

## ✨ Funcionalidades

- **Registro de feiras e compras:** cadastre cada feira do mês com todos os produtos, quantidades e preços.
- **Categorias organizadas:** produtos de limpeza, frutas e legumes, despensa/básico, açougue/frios, laticínios e higiene.
- **Itens essenciais:** marque os produtos que não podem faltar em casa (arroz, feijão, açúcar, leite, café...) e confira rapidamente se algum ficou de fora da lista.
- **Comparação entre meses:** compare feiras de meses diferentes e veja a evolução dos preços de cada produto.
- **Produtos mais consumidos:** descubra o que mais pesa no seu orçamento e o que você mais compra.

## 🎯 Objetivo

Ajudar famílias a planejar melhor as compras, evitar esquecimentos e economizar, mostrando de forma clara para onde vai o dinheiro do mês.

## 🛠️ Tecnologias

- [Flutter](https://flutter.dev/) e Dart
- Firebase Authentication (e-mail e senha)
- Cloud Firestore para dados separados por usuário
- SQLite local existente (os registros antigos permanecem no dispositivo e não são migrados automaticamente)

## 🚀 Como executar

Pré-requisito: ter o [Flutter SDK](https://docs.flutter.dev/get-started/install) instalado.

```bash
# Clone o repositório
git clone [https://github.com/mariovieira-dev/feira_facil]


# Instale as dependências
flutter pub get

# Configure o Firebase Authentication com o provedor E-mail/senha e crie o
# banco Cloud Firestore no projeto configurado em lib/firebase_options.dart.
# Publique as regras de acesso:
firebase deploy --only firestore:rules

# Execute o app (com um celular conectado ou emulador aberto)
flutter run
```

Após o cadastro ou login, os novos dados são armazenados em caminhos como
`users/{uid}/products`, `users/{uid}/purchases/{purchaseId}/items` e
`users/{uid}/budgets`. A conta começa sem copiar os dados antigos do SQLite.

## 🗺️ Próximos passos

- [ ] Gráficos de gastos por categoria
- [ ] Lista de compras com base nos itens essenciais
- [ ] Exportar o histórico de feiras
- [ ] Backup dos dados

## 👤 Autor

Desenvolvido por **Mario Vieira**, a partir de uma ideia da minha esposa. 💚