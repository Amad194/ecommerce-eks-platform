{{- define "common.ingress" -}}
{{- if .Values.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "common.fullname" . }}
  labels:
    {{- include "common.labels" . | nindent 4 }}
  annotations:
    {{- if .Values.ingress.tls }}
    cert-manager.io/cluster-issuer: {{ .Values.ingress.clusterIssuer | default "letsencrypt-prod" }}
    {{- end }}
    external-dns.alpha.kubernetes.io/hostname: {{ .Values.ingress.host | quote }}
    {{- with .Values.ingress.annotations }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  ingressClassName: {{ .Values.ingress.className }}
  {{- if .Values.ingress.tls }}
  tls:
    - hosts:
        - {{ .Values.ingress.host | quote }}
      secretName: {{ include "common.fullname" . }}-tls
  {{- end }}
  rules:
    - host: {{ .Values.ingress.host | quote }}
      http:
        paths:
          - path: {{ .Values.ingress.path | default "/" }}
            pathType: {{ .Values.ingress.pathType | default "Prefix" }}
            backend:
              service:
                name: {{ include "common.fullname" . }}
                port:
                  number: {{ .Values.service.port }}
{{- end -}}
{{- end -}}
