/* Copyright 2015 Yorba Foundation
 *
 * This software is licensed under the GNU Lesser General Public License
 * (version 2.1 or later).  See the COPYING file in this distribution.
 */

public class AccountDialogEditAlternateEmailsPane : AccountDialogPane {
    private class ListItem : Gtk.Label {
        public Geary.RFC822.MailboxAddress mailbox;
        
        public ListItem(Geary.RFC822.MailboxAddress mailbox) {
            this.mailbox = mailbox;
            
            label = "<b>%s</b>".printf(mailbox.address);
            use_markup = true;
            ellipsize = Pango.EllipsizeMode.END;
        }
    }
    
    public string? email { get; private set; default = null; }
    
    public bool changed { get; private set; default = false; }
    
    public string? selected { get; private set; default = null; }
    
    private Gtk.Label title_label;
    private Gtk.Entry email_entry;
    private Gtk.Button add_button;
    private Gtk.ListBox address_listbox;
    private Gtk.ToolButton delete_button;
    private Gtk.Button cancel_button;
    private Gtk.Button save_button;
    
    private Geary.RFC822.MailboxAddress? primary_mailbox = null;
    private Gee.HashSet<string> email_addresses = new Gee.HashSet<string>(
        Geary.String.stri_hash, Geary.String.stri_equal);
    
    public signal void cancelled();
    
    public AccountDialogEditAlternateEmailsPane(Gtk.Stack stack) {
        base (stack);
        
        Gtk.Builder builder = GearyApplication.instance.create_builder("edit_alternate_emails.glade");
        
        // Primary container
        pack_start((Gtk.Widget) builder.get_object("container"));
        
        title_label = (Gtk.Label) builder.get_object("title_label");
        email_entry = (Gtk.Entry) builder.get_object("email_entry");
        add_button = (Gtk.Button) builder.get_object("add_button");
        address_listbox = (Gtk.ListBox) builder.get_object("address_listbox");
        delete_button = (Gtk.ToolButton) builder.get_object("delete_button");
        cancel_button = (Gtk.Button) builder.get_object("cancel_button");
        save_button = (Gtk.Button) builder.get_object("save_button");
        
        email_entry.bind_property("text", add_button, "sensitive", BindingFlags.SYNC_CREATE,
            transform_email_to_sensitive);
        bind_property("changed", save_button, "sensitive", BindingFlags.SYNC_CREATE);
        bind_property("selected", delete_button, "sensitive", BindingFlags.SYNC_CREATE);
        
        cancel_button.clicked.connect(() => { cancelled(); });
        add_button.clicked.connect(on_add_clicked);
    }
    
    private bool transform_email_to_sensitive(Binding binding, Value source, ref Value target) {
        target = Geary.RFC822.MailboxAddress.is_valid_address(email_entry.text);
        
        return true;
    }
    
    public void set_account(Geary.AccountInformation account_info) {
        email = account_info.email;
        primary_mailbox = account_info.get_primary_mailbox_address();
        changed = false;
        
        // reset/clear widgets
        title_label.label = _("Additional addresses for %s").printf(account_info.email);
        email_entry.text = "";
        
        // clear listbox
        foreach (Gtk.Widget widget in address_listbox.get_children())
            address_listbox.remove(widget);
        
        // Add all except for primary; this does not constitute a change per se
        foreach (string email_address in account_info.get_all_email_addresses())
            add_email_address(email_address, false);
    }
    
    private void add_email_address(string email_address, bool is_change) {
        if (email_addresses.contains(email_address))
            return;
        
        if (!Geary.RFC822.MailboxAddress.is_valid_address(email_address))
            return;
        
        if (Geary.String.stri_equal(email_address, primary_mailbox.address))
            return;
        
        email_addresses.add(email_address);
        
        ListItem item = new ListItem(new Geary.RFC822.MailboxAddress(null, email_address));
        item.show_all();
        address_listbox.add(item);
        
        if (is_change)
            changed = true;
    }
    
    private void on_add_clicked() {
        add_email_address(email_entry.text, true);
    }
}

