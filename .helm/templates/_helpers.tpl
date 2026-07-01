{{- define "spark.labels" -}}
app.kubernetes.io/name: {{ .Values.appName }}
app.kubernetes.io/part-of: {{ .Values.appName }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "spark.image" -}}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag -}}
{{- end -}}

{{- define "spark.securityContext" -}}
runAsNonRoot: true
runAsUser: 185
fsGroup: 185
seccompProfile:
  type: RuntimeDefault
{{- end -}}

{{- define "spark.containerSecurityContext" -}}
readOnlyRootFilesystem: true
allowPrivilegeEscalation: false
capabilities:
  drop: ["ALL"]
{{- end -}}
