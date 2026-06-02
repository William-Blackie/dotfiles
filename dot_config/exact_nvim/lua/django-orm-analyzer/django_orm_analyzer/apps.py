"""Django application configuration for Django ORM Analyzer."""

from django.apps import AppConfig


class DjangoORMAnalyzerConfig(AppConfig):
    """App configuration for the Django ORM Analyzer package."""

    default_auto_field = "django.db.models.BigAutoField"
    name = "django_orm_analyzer"
    verbose_name = "Django ORM Query Complexity Analyzer"
