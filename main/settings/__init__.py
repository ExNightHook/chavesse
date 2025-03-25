try:
    from .local import *  # noqa
except ImportError:
    from django.conf import ImproperlyConfigured

    raise ImproperlyConfigured('''

    Please create local settings file as described in README.

    ''')
