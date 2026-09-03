# DS713+ — note de recherche sur le DOM USB interne

Le DS713+ contient un DOM de 128 MB. Les systèmes Synology x86 de cette génération exposent leur DOM de boot comme un périphérique USB mass-storage `f400:f400`; il ne faut donc pas traiter le connecteur interne comme un SATA DOM standard.

Des réparations documentées sur la famille Cedarview proche (notamment DS412+) montrent un eDOM USB à connecteur 9/10 broches dont seulement quatre lignes sont nécessaires : +5 V, D-, D+ et GND. Des témoignages indiquent les broches paires 2/4/6/8 sur ce module, ce qui **n'est pas le brochage d'un header USB PC standard**.

Conséquence : le fait qu'une clé USB ordinaire ne fonctionne pas lorsqu'elle est raccordée directement au connecteur DOM/J2 ne prouve pas que le port doit être "réveillé" électriquement. Un brochage non standard ou un adaptateur incorrect est une explication au moins aussi plausible.

Les kernels Synology possèdent par ailleurs une infrastructure de contrôle USB VBUS par GPIO (`gSynoUsbVbus*`). Cela prouve que Synology commande l'alimentation de certains ports USB sur certains modèles, mais le mapping DS713+ DOM/J2 n'est pas encore établi. Il serait donc dangereux de toggler des GPIO au hasard.

Statut : **piste ouverte**. La prochaine étape correcte est de déterminer le contrôleur/root-port du DOM stock et le brochage exact J2 à partir du matériel/source/firmware DS713+, puis seulement de chercher un éventuel GPIO VBUS/reset.

## Mise à jour après essais physiques v9.4/v9.5

Le brochage effectivement utilisé sur J2 a été :

```text
pin 2  = +5 V
pin 4  = D-
pin 6  = D+
pin 8  = GND
pin 10 = non utilisé pour ce canal USB
```

Résultats :

```text
v9.4 sur J2 -> aucun boot
v9.5 sur J2 -> aucun boot
même média v9.5 remis en façade -> boot Etron arrière + SATA power OK
```

Le firmware du NAS utilisé pour ces essais contient déjà le bypass `F400:F400` validé. L'hypothèse « la clé J2 échoue simplement parce qu'elle n'est pas F400:F400 » n'est donc pas retenue comme explication actuelle.

La recherche doit désormais distinguer au moins : présence/chronologie de VBUS sur J2, éventuel enable/reset spécifique, ordre d'énumération DXE/BDS et éventuel chemin de boot DOM interne distinct du `UsbBusDxe` patché. Aucun GPIO ne doit être basculé au hasard.
