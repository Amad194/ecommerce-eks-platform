{{- define "common.externalsecret" -}}
{{- if .Values.externalSecret.enabled -}}
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: {{ include "common.fullname" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
spec:
  refreshInterval: {{ .Values.externalSecret.refreshInterval | default "1h" }}
  secretStoreRef:
    name: {{ .Values.externalSecret.secretStoreRef | default "aws-secrets-manager" }}
    kind: ClusterSecretStore
  target:
    name: {{ include "common.fullname" . }}-secret
    creationPolicy: Owner
  data:
    {{- toYaml .Values.externalSecret.data | nindent 4 }}
{{- end -}}
{{- end -}}
