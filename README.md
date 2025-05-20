## Contexte du Projet
Je développe une application dédiée à l’Hyrox, permettant de lancer des entraînements depuis l’Apple Watch ou l’iPhone, tout en fixant des objectifs à atteindre pour suivre sa progression.

## Structure du Projet
- **Un projet swift ui avec 2 target iOS et watchOS
- **Core data et WCSession

## Modèle de Prompt

**Objectif principal** : [BUT DE LA FONCTIONNALITÉ]

**Utilisateurs cibles** :
- [ ] Sportif pratiquant l’hyrox

### 2. RÉFÉRENCE D'IMPLÉMENTATION

**Arboressence hyrox ios** :
- /Constante (partagé entre les targets)
- /Extensions (partagé entre les targets)
- /Manager (partagé entre les targets)
- /Models (partagé entre les targets)
- /ViewModels (partagé entre les targets)
- /View
- ContentView
- PeristenceController (partagé entre les targets)
- Fichier core data hyrox (partagé entre les targets)

**Arboressence hyrox watchOS** :
- ContentView
- WatchWorkoutView
```
